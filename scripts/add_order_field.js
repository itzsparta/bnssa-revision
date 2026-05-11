// Ajoute le champ `order` (1-31) à chaque thème Firebase
// Usage: node add_order_field.js <serviceAccount.json>

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = process.argv[2];
if (!serviceAccountPath) {
  console.error('Usage: node add_order_field.js <serviceAccount.json>');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
  projectId: 'bnssa-pro',
});

const db = admin.firestore();

const ORDERED_THEMES = [
  'theme_reglementation_et_organisation',
  'theme_signalisation_de_plage',
  'theme_navigation_balisage_maritime',
  'theme_secourisme_physiopathologie',
  'theme_responsabilites_cadre_juridique',
  'theme_surveillance_des_groupes_acm',
  'theme_environnement_meteo_ocean',
  'theme_surveillance_situations_concretes',
  'theme_complements_organisation_administrative',
  'theme_techniques_de_sauvetage_zone',
  'theme_hygiene_piscine_organisation',
  'theme_meteo_radio_vhf_navigation',
  'theme_physiopathologie_secourisme_avance',
  'theme_meteo_avancee_oceanographie',
  'theme_synthese_secourisme_situationnel',
  'theme_droit_obligations_juridiques_expert',
  'theme_physiopathologie_secourisme_expert',
  'theme_situations_d',
  'theme_culture_maritime_secourisme_final',
  'theme_procedures_zone_de_sauvetage',
  'theme_secourisme_interventions',
  'theme_cadre_administratif_organisation',
  'theme_traumatologie_secourisme',
  'theme_meteo_comms_securite',
  'theme_secourisme_pse1_pse2',
  'theme_zone_sauvetage_operationnel',
  'theme_reglementation_organisation_securite',
  'theme_administration_cadre_legal',
  'theme_secourisme_operationnel',
  'theme_milieu_de_mer_risques_locaux',
  'theme_secourisme_loi',
];

async function run() {
  const batch = db.batch();
  for (let i = 0; i < ORDERED_THEMES.length; i++) {
    const ref = db.collection('themes').doc(ORDERED_THEMES[i]);
    batch.update(ref, { order: i + 1 });
  }
  await batch.commit();
  console.log(`${ORDERED_THEMES.length} thèmes mis à jour avec le champ order.`);
}

run().catch(err => { console.error(err); process.exit(1); });
