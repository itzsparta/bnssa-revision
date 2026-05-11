// Push questions.txt → Firebase (remplace tout)
// Usage: node push_to_firebase.js <serviceAccount.json>

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = process.argv[2];
if (!serviceAccountPath) {
  console.error('Usage: node push_to_firebase.js <serviceAccount.json>');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
  projectId: 'bnssa-pro',
});
const db = admin.firestore();

// ─── Parser ──────────────────────────────────────────────────────────────────

function slugify(title) {
  return 'theme_' + title
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '') // enlève accents
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function extractField(block, field) {
  const re = new RegExp("['\"]" + field + "['\"]\\s*:\\s*\"((?:[^\\\\\"]|\\\\.)*)\"", 'i');
  const m = block.match(re);
  if (m) return m[1].replace(/\\"/g, '"');
  const re2 = new RegExp("['\"]" + field + "['\"]\\s*:\\s*'((?:[^\\\\']|\\\\.)*)'", 'i');
  const m2 = block.match(re2);
  if (m2) return m2[1].replace(/\\'/g, "'");
  return null;
}

function extractNumber(block, field) {
  const m = block.match(new RegExp("['\"]" + field + "['\"]\\s*:\\s*(\\d+)"));
  return m ? parseInt(m[1]) : null;
}

function extractOptions(block) {
  const start = block.indexOf("'options'");
  if (start === -1) return null;
  const arrStart = block.indexOf('[', start);
  if (arrStart === -1) return null;
  let depth = 0, arrEnd = -1;
  for (let k = arrStart; k < block.length; k++) {
    if (block[k] === '[') depth++;
    else if (block[k] === ']') { depth--; if (depth === 0) { arrEnd = k; break; } }
  }
  if (arrEnd === -1) return null;
  const arrStr = block.slice(arrStart, arrEnd + 1);
  const opts = [];
  const strRe = /"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'/g;
  let sm;
  while ((sm = strRe.exec(arrStr)) !== null) {
    opts.push((sm[1] !== undefined ? sm[1] : sm[2]).replace(/\\"/g, '"').replace(/\\'/g, "'"));
  }
  return opts.length >= 2 ? opts : null;
}

function parseQuestionsTxt(text) {
  const themes = [];
  let currentTheme = null;
  const lines = text.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Nouveau bloc thème
    const titleMatch = line.match(/['"]title['"]\s*:\s*['"]([^'"]+)['"]/);
    const iconMatch  = lines[i + 1]?.match(/['"]icon['"]\s*:\s*['"]([^'"]+)['"]/);
    if (titleMatch && iconMatch) {
      currentTheme = { title: titleMatch[1], icon: iconMatch[1], questions: [] };
      themes.push(currentTheme);
      i++; // sauter la ligne icon
      continue;
    }

    // Question
    if (!line.includes("questionText") || !currentTheme) continue;

    // Collecter le bloc (peut être multi-lignes)
    let block = line;
    let j = i;
    while (j < lines.length) {
      const combined = lines.slice(i, j + 1).join('\n');
      if (combined.includes("'explanation'") || combined.includes('"explanation"')) {
        block = combined; break;
      }
      j++;
      if (j - i > 30) break;
    }

    const qt   = extractField(block, 'questionText');
    const opts = extractOptions(block);
    const cai  = extractNumber(block, 'correctAnswerIndex');
    const exp  = extractField(block, 'explanation');

    if (qt && opts && cai !== null && exp) {
      currentTheme.questions.push({ questionText: qt, options: opts, correctAnswerIndex: cai, explanation: exp });
      i = j;
    }
  }

  return themes;
}

// ─── Firebase ─────────────────────────────────────────────────────────────────

async function deleteCollection(colRef) {
  const snap = await colRef.get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
}

async function push() {
  const text = fs.readFileSync(path.join(__dirname, '..', 'questions.txt'), 'utf8');
  const themes = parseQuestionsTxt(text);

  const totalQ = themes.reduce((s, t) => s + t.questions.length, 0);
  console.log(`Parsed: ${themes.length} thèmes, ${totalQ} questions`);

  // 1. Supprimer tous les anciens thèmes
  console.log('\n[1/3] Suppression des anciens thèmes...');
  const oldThemes = await db.collection('themes').get();
  for (const doc of oldThemes.docs) {
    await deleteCollection(doc.ref.collection('questions'));
    await doc.ref.delete();
    process.stdout.write('.');
  }
  console.log(` ${oldThemes.size} thèmes supprimés`);

  // 2. Créer les nouveaux thèmes + questions
  console.log('\n[2/3] Push des nouveaux thèmes...');
  let qCount = 0;

  for (const theme of themes) {
    const themeId = slugify(theme.title);
    const themeRef = db.collection('themes').doc(themeId);

    await themeRef.set({ title: theme.title, icon: theme.icon });

    // Push questions par batch de 400
    const BATCH = 400;
    for (let i = 0; i < theme.questions.length; i += BATCH) {
      const batch = db.batch();
      const chunk = theme.questions.slice(i, i + BATCH);
      chunk.forEach(q => {
        const ref = themeRef.collection('questions').doc();
        batch.set(ref, q);
      });
      await batch.commit();
      qCount += chunk.length;
    }
    console.log(`  ✓ ${themeId} (${theme.questions.length} questions)`);
  }

  // 3. Résumé
  console.log(`\n[3/3] Terminé. ${themes.length} thèmes, ${qCount} questions pushées.`);
}

push().catch(err => { console.error(err); process.exit(1); });
