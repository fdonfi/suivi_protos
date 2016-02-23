-------------------------------------------------------------
------------Insertion des dictionnaires taxref --------------
-------------------------------------------------------------

SET search_path = taxonomie, pg_catalog;
--
-- TOC entry 3270 (class 0 OID 17759)
-- Dependencies: 242
-- Data for Name: bib_taxref_habitats; Type: TABLE DATA; Schema: taxonomie; Owner: geonatuser
--

INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (1, 'Marin');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (2, 'Eau douce');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (3, 'Terrestre');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (5, 'Marin et Terrestre');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (6, 'Eau Saumâtre');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (7, 'Continental (Terrestre et/ou Eau douce)');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (0, 'Non renseigné');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (4, 'Marin et Eau douce');
INSERT INTO bib_taxref_habitats (id_habitat, nom_habitat) VALUES (8, 'Continental (Terrestre et Eau douce)');


--
-- TOC entry 3271 (class 0 OID 17762)
-- Dependencies: 243
-- Data for Name: bib_taxref_rangs; Type: TABLE DATA; Schema: taxonomie; Owner: geonatuser
--

INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('KD  ', 'Règne');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('PH  ', 'Embranchement');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('CL  ', 'Classe');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('OR  ', 'Ordre');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('FM  ', 'Famille');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('GN  ', 'Genre');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('AGES', 'Agrégat');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('ES  ', 'Espèce');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('SSES', 'Sous-espèce');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('HYB ', 'Hybride');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('CVAR', 'Convariété');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('VAR ', 'Variété');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('FO  ', 'Forme');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('SSFO', 'Sous-Forme');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('RACE', 'Race');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('CAR', '?');
INSERT INTO bib_taxref_rangs (id_rang, nom_rang) VALUES ('SVAR', 'Sous-variété');


--
-- TOC entry 3272 (class 0 OID 17765)
-- Dependencies: 244
-- Data for Name: bib_taxref_statuts; Type: TABLE DATA; Schema: taxonomie; Owner: geonatuser
--

INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('A', 'Absente');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('B', 'Accidentelle / Visiteuse');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('C', 'Cryptogène');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('D', 'Douteux');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('E', 'Endemique');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('F', 'Trouvé en fouille');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('I', 'Introduite');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('J', 'Introduite envahissante');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('M', 'Domestique / Introduite non établie');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('P', 'Présente');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('S', 'Subendémique');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('W', 'Disparue');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('X', 'Eteinte');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('Y', 'Introduite éteinte');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('Z', 'Endémique éteinte');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('0', 'Non renseigné');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES ('Q', 'Mentionné par erreur');
INSERT INTO bib_taxref_statuts (id_statut, nom_statut) VALUES (' ', 'Non précisé');


-------------------------------------------------------------
------------Insertion des données taxref	-------------
-------------------------------------------------------------

---import taxref--
DROP TABLE import_taxref;

CREATE TABLE taxonomie.import_taxref
(
  regne character varying(20),
  phylum character varying(50),
  classe character varying(50),
  ordre character varying(50),
  famille character varying(50),
  group1_inpn character varying(50),
  group2_inpn character varying(50),
  cd_nom integer NOT NULL,
  cd_taxsup integer,
  cd_ref integer,
  rang character varying(10),
  lb_nom character varying(100),
  lb_auteur character varying(250),
  nom_complet character varying(255),
  nom_complet_html character varying(500),
  nom_valide character varying(255),
  nom_vern character varying(1000),
  nom_vern_eng character varying(500),
  habitat character varying(10),
  fr character varying(10),
  gf character varying(10),
  mar character varying(10),
  gua character varying(10),
  sm character varying(10),
  sb character varying(10),
  spm character varying(10),
  may character varying(10),
  epa character varying(10),
  reu character varying(10),
  taaf character varying(10),
  pf character varying(10),
  nc character varying(10),
  wf character varying(10),
  cli character varying(10),
  url text,
  CONSTRAINT pk_import_taxref PRIMARY KEY (cd_nom)
)
WITH (
  OIDS=FALSE
);

COPY import_taxref (regne, phylum, classe, ordre, famille, group1_inpn, group2_inpn, 
          cd_nom, cd_taxsup, cd_ref, rang, lb_nom, lb_auteur, nom_complet, nom_complet_html,
          nom_valide, nom_vern, nom_vern_eng, habitat, fr, gf, mar, gua, 
          sm, sb, spm, may, epa, reu, taaf, pf, nc, wf, cli, url)
FROM  'PATH_TO_DIR/data/inpn/TAXREFv80.txt'
WITH  CSV HEADER 
DELIMITER E'\t'  encoding 'LATIN1';

---selection des taxons faune uniquement--

--Modification de la colonne nom_vern suite au changement de référentiel
ALTER TABLE taxref ALTER COLUMN nom_vern TYPE varchar(1000);

TRUNCATE TABLE taxref CASCADE;
INSERT INTO taxref
      SELECT cd_nom, fr as id_statut, habitat::int as id_habitat, rang as  id_rang, regne, phylum, classe, 
             ordre, famille, cd_taxsup, cd_ref, lb_nom, substring(lb_auteur, 1, 150), nom_complet, 
             nom_valide, nom_vern, nom_vern_eng, group1_inpn, group2_inpn
        FROM import_taxref
        WHERE regne = 'Animalia'
        OR regne = 'Fungi'
        OR regne = 'Plantae';


----PROTECTION

---import des statuts de protections
TRUNCATE TABLE taxref_protection_articles CASCADE;
COPY taxref_protection_articles (
cd_protection, article, intitule, protection, arrete, fichier, 
fg_afprot, niveau, cd_arrete, url, date_arrete, rang_niveau, 
lb_article, type_protection
)
FROM  'PATH_TO_DIR/data/inpn/PROTECTION_ESPECES_TYPES_70.csv'
WITH  CSV HEADER 
DELIMITER ';'  encoding 'LATIN1';


---import des statuts de protections associés au taxon
CREATE TABLE import_protection_especes (
	CD_NOM int,
	CD_PROTECTION varchar(250),
	NOM_CITE text,
	SYN_CITE text,
	NOM_FRANCAIS_CITE text,
	PRECISIONS varchar(500),
	CD_NOM_CITE int
);

COPY import_protection_especes
FROM  'PATH_TO_DIR/data/inpn/PROTECTION_ESPECES_70.csv'
WITH  CSV HEADER 
DELIMITER ';'  encoding 'LATIN1';


TRUNCATE TABLE taxref_protection_especes;
INSERT INTO taxref_protection_especes
SELECT DISTINCT  p.* 
FROM  (
  SELECT cd_nom , cd_protection , string_agg(DISTINCT nom_cite, ',') nom_cite, 
    string_agg(DISTINCT syn_cite, ',')  syn_cite, string_agg(DISTINCT nom_francais_cite, ',')  nom_francais_cite,
    string_agg(DISTINCT precisions, ',')  precisions, cd_nom_cite 
  FROM   import_protection_especes
  GROUP BY cd_nom , cd_protection , cd_nom_cite 
) p
JOIN taxref t
USING(cd_nom) ;

DROP TABLE  import_protection_especes;


--- Nettoyage des statuts de protections non utilisés
DELETE FROM  taxref_protection_articles
WHERE cd_protection IN (
  SELECT cd_protection 
  FROM taxref_protection_articles
  WHERE NOT cd_protection IN (SELECT DISTINCT cd_protection FROM  taxref_protection_especes)
);


--- Activation des textes valides pour la structure
--      Par défaut activation de tous les textes nationaux et internationaux
--          Pour des considérations locales à faire au cas par cas !!!
UPDATE  taxonomie.taxref_protection_articles SET concerne_mon_territoire = true
WHERE cd_protection IN (
	SELECT cd_protection
	FROM  taxonomie.taxref_protection_articles
	WHERE
		niveau IN ('international', 'national', 'communautaire')
		AND type_protection = 'Protection'
);
