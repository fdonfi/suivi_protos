--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: chiro; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA chiro;


--
-- Name: lexique; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA lexique;


--
-- Name: SCHEMA lexique; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA lexique IS 'données "externes"';


--
-- Name: ref_geographique; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ref_geographique;


--
-- Name: suivi; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA suivi;


--
-- Name: taxonomie; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA taxonomie;


--
-- Name: utilisateurs; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA utilisateurs;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


SET search_path = suivi, pg_catalog;

--
-- Name: fct_get_user_name(integer); Type: FUNCTION; Schema: suivi; Owner: -
--

CREATE FUNCTION fct_get_user_name(id integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
begin
	return (select upper(nom_role::text) || ' '::text || prenom_role::TEXT as txt from utilisateurs.t_roles WHERE id_role=id);
end
$$;


--
-- Name: fct_trg_add_obs_geom(); Type: FUNCTION; Schema: suivi; Owner: -
--

CREATE FUNCTION fct_trg_add_obs_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if(NEW.geom is NULL and NEW.fk_bs_id IS NOT NULL) THEn
		NEW.geom = (select geom from suivi.pr_base_site WHERE id=NEW.fk_bs_id);
	end if;
	return NEW;
end;
$$;


--
-- Name: fct_trg_commune_from_geom(); Type: FUNCTION; Schema: suivi; Owner: -
--

CREATE FUNCTION fct_trg_commune_from_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if(NEW.geom is not NULL) THEN
		if(TG_TABLE_NAME = 'pr_base_site') THEN
			NEW.bs_ref_commune = array(select a.insee_com from ref_geographique.l_communes a where st_intersects(st_transform(NEW.geom, 2154), a.geom) order by a.insee_com);
		ELSIF(TG_TABLE_NAME = 'pr_base_visite') THEN
			NEW.bv_ref_commune = array(select a.insee_com from ref_geographique.l_communes a where st_intersects(st_transform(NEW.geom, 2154), a.geom) order by a.insee_com);
		END IF;	
	elsif(TG_TABLE_NAME = 'pr_base_visite') THEN
		NEW.bv_ref_commune = (select bs_ref_commune from suivi.pr_base_site where id=NEW.site_id);
	END IF;
	return NEW;
end;
$$;


--
-- Name: fct_trg_date_changes(); Type: FUNCTION; Schema: suivi; Owner: -
--

CREATE FUNCTION fct_trg_date_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if(TG_OP = 'INSERT') THEN
		NEW.meta_create_timestamp = NOW();
	ELSIF(TG_OP = 'UPDATE') THEN
		NEW.meta_update_timestamp = NOW();
		if(NEW.meta_create_timestamp IS NULL) THEN
			NEW.meta_create_timestamp = NOW();
		END IF;
	end IF;
	return NEW;
end;
$$;


--
-- Name: fct_trg_gen_bs_code(); Type: FUNCTION; Schema: suivi; Owner: -
--

CREATE FUNCTION fct_trg_gen_bs_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE new_bs_code varchar;
BEGIN

	new_bs_code = (SELECT DISTINCT (unique_code || '_' ||  COALESCE(prochain_id, 1))::varchar
		FROM (SELECT * FROM ref_geographique.l_communes  ) c
		LEFT OUTER JOIN (
			SELECT DISTINCT max(split_part(bs_code, '_', 3)::int+1) OVER (PARTITION BY (regexp_matches(a.bs_code, '(.*?)(_\d+)$'))[1])  as prochain_id  ,
				(regexp_matches(a.bs_code, '(.*?)(_\d+)$'))[1] as commune
			FROM suivi.pr_base_site a
		) a
		ON a.commune =c.unique_code
		WHERE  st_intersects(geom ,st_transform(NEW.geom, 2154)));
	
	IF (TG_OP = 'INSERT') THEN
		NEW.bs_code := new_bs_code;
	ELSIF(TG_OP = 'UPDATE') THEN
		IF (select (regexp_matches(NEW.bs_code, '(.*?)(_\d+)$'))[1] <> (select (regexp_matches(new_bs_code, '(.*?)(_\d+)$'))[1])) OR NEW.bs_code is null THEN
			NEW.bs_code := new_bs_code;
		END IF;
	END IF;
	RETURN NEW;
END;
$_$;


SET search_path = taxonomie, pg_catalog;

--
-- Name: find_cdref(integer); Type: FUNCTION; Schema: taxonomie; Owner: -
--

CREATE FUNCTION find_cdref(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
--fonction permettant de renvoyer le cd_ref d'un taxon à partir de son cd_nom
--
--Gil DELUERMOZ septembre 2011

  DECLARE ref integer;
  BEGIN
	SELECT INTO ref cd_ref FROM taxonomie.taxref WHERE cd_nom = id;
	return ref;
  END;
$$;


SET search_path = utilisateurs, pg_catalog;

--
-- Name: modify_date_insert(); Type: FUNCTION; Schema: utilisateurs; Owner: -
--

CREATE FUNCTION modify_date_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_insert := now();
    NEW.date_update := now();
    RETURN NEW;
END;
$$;


--
-- Name: modify_date_update(); Type: FUNCTION; Schema: utilisateurs; Owner: -
--

CREATE FUNCTION modify_date_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_update := now();
    RETURN NEW;
END;
$$;


SET search_path = chiro, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: pr_site_infos; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE pr_site_infos (
    id integer NOT NULL,
    fk_bs_id integer NOT NULL,
    cis_description text,
    cis_menace_cmt text,
    cis_contact_nom character varying(25) DEFAULT NULL::character varying,
    cis_contact_prenom character varying(25) DEFAULT NULL::character varying,
    cis_contact_adresse character varying(150) DEFAULT NULL::character varying,
    cis_contact_code_postal character varying(5) DEFAULT NULL::character varying,
    cis_contact_ville character varying(100) DEFAULT NULL::character varying,
    cis_contact_telephone character varying(15) DEFAULT NULL::character varying,
    cis_contact_portable character varying(15) DEFAULT NULL::character varying,
    cis_contact_commentaire text,
    cis_frequentation integer,
    cis_menace integer,
    cis_site_actif boolean,
    cis_actions text
);


--
-- Name: pr_site_infos_id_seq; Type: SEQUENCE; Schema: chiro; Owner: -
--

CREATE SEQUENCE pr_site_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pr_site_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: chiro; Owner: -
--

ALTER SEQUENCE pr_site_infos_id_seq OWNED BY pr_site_infos.id;


--
-- Name: pr_visite_conditions; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE pr_visite_conditions (
    id integer NOT NULL,
    fk_bv_id integer NOT NULL,
    cvc_temperature numeric(4,2),
    cvc_humidite numeric(4,2),
    cvc_mod_id integer
);


--
-- Name: pr_visite_conditions_id_seq; Type: SEQUENCE; Schema: chiro; Owner: -
--

CREATE SEQUENCE pr_visite_conditions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pr_visite_conditions_id_seq; Type: SEQUENCE OWNED BY; Schema: chiro; Owner: -
--

ALTER SEQUENCE pr_visite_conditions_id_seq OWNED BY pr_visite_conditions.id;


--
-- Name: pr_visite_observationtaxon; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE pr_visite_observationtaxon (
    id integer NOT NULL,
    fk_bv_id integer NOT NULL,
    cotx_tx_presume character varying(250) DEFAULT NULL::character varying,
    cotx_espece_incertaine boolean DEFAULT false NOT NULL,
    cotx_effectif_abs integer,
    cotx_nb_male_adulte integer,
    cotx_nb_femelle_adulte integer,
    cotx_nb_male_juvenile integer,
    cotx_nb_femelle_juvenile integer,
    cotx_nb_male_indetermine integer,
    cotx_nb_femelle_indetermine integer,
    cotx_nb_indetermine_indetermine integer,
    cotx_obj_status_validation integer,
    cotx_commentaire character varying(1000),
    cotx_nb_indetermine_juvenile integer,
    cotx_nb_indetermine_adulte integer,
    cotx_validateur integer,
    cotx_cd_nom integer,
    cotx_nom_complet character varying(255),
    cotx_mod_id integer,
    cotx_act_id integer,
    cotx_eff_id integer,
    cotx_prv_id integer,
    cotx_num_id integer,
    cotx_date_validation date,
    meta_create_timestamp date,
    meta_update_timestamp date,
    meta_numerisateur_id integer,
    cotx_indices_cmt character varying(1000)
);


--
-- Name: pr_visite_observationtaxon_id_seq; Type: SEQUENCE; Schema: chiro; Owner: -
--

CREATE SEQUENCE pr_visite_observationtaxon_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pr_visite_observationtaxon_id_seq; Type: SEQUENCE OWNED BY; Schema: chiro; Owner: -
--

ALTER SEQUENCE pr_visite_observationtaxon_id_seq OWNED BY pr_visite_observationtaxon.id;


--
-- Name: rel_chirosite_fichiers; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE rel_chirosite_fichiers (
    site_id integer NOT NULL,
    fichier_id integer NOT NULL,
    commentaire character varying(100)
);


--
-- Name: rel_chirosite_thesaurus_amenagement; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE rel_chirosite_thesaurus_amenagement (
    site_id integer NOT NULL,
    thesaurus_id integer NOT NULL
);


--
-- Name: rel_chirosite_thesaurus_menace; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE rel_chirosite_thesaurus_menace (
    site_id integer NOT NULL,
    thesaurus_id integer NOT NULL
);


--
-- Name: rel_observationtaxon_fichiers; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE rel_observationtaxon_fichiers (
    cotx_id integer NOT NULL,
    fichier_id integer NOT NULL,
    commentaire character varying(100)
);


--
-- Name: rel_observationtaxon_thesaurus_indice; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE rel_observationtaxon_thesaurus_indice (
    cotx_id integer NOT NULL,
    thesaurus_id integer NOT NULL
);


--
-- Name: subpr_observationtaxon_biometrie; Type: TABLE; Schema: chiro; Owner: -; Tablespace: 
--

CREATE TABLE subpr_observationtaxon_biometrie (
    id integer NOT NULL,
    fk_cotx_id integer NOT NULL,
    cbio_age_id integer,
    cbio_sexe_id integer,
    cbio_ab double precision DEFAULT NULL::numeric,
    cbio_poids double precision DEFAULT NULL::numeric,
    cbio_d3mf1 double precision DEFAULT NULL::numeric,
    cbio_d3f2f3 double precision DEFAULT NULL::numeric,
    cbio_d3total double precision DEFAULT NULL::numeric,
    cbio_d5 double precision DEFAULT NULL::numeric,
    cbio_cm3sup double precision DEFAULT NULL::numeric,
    cbio_cm3inf double precision DEFAULT NULL::numeric,
    cbio_cb double precision DEFAULT NULL::numeric,
    cbio_lm double precision DEFAULT NULL::numeric,
    cbio_oreille double precision DEFAULT NULL::numeric,
    cbio_commentaire character varying(1000),
    meta_create_timestamp date,
    meta_update_timestamp date,
    meta_numerisateur_id integer
);


--
-- Name: subpr_observationtaxon_biometrie_id_seq; Type: SEQUENCE; Schema: chiro; Owner: -
--

CREATE SEQUENCE subpr_observationtaxon_biometrie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subpr_observationtaxon_biometrie_id_seq; Type: SEQUENCE OWNED BY; Schema: chiro; Owner: -
--

ALTER SEQUENCE subpr_observationtaxon_biometrie_id_seq OWNED BY subpr_observationtaxon_biometrie.id;


SET search_path = suivi, pg_catalog;

--
-- Name: pr_base_site; Type: TABLE; Schema: suivi; Owner: -; Tablespace: 
--

CREATE TABLE pr_base_site (
    id integer NOT NULL,
    bs_obr_id integer,
    bs_type_id integer NOT NULL,
    bs_nom character varying(250) NOT NULL,
    bs_code character varying(25) DEFAULT NULL::character varying,
    bs_date date,
    bs_description text,
    geom public.geometry,
    bs_ref_commune character varying[],
    meta_create_timestamp date,
    meta_update_timestamp date,
    meta_numerisateur_id integer
);


--
-- Name: pr_base_visite; Type: TABLE; Schema: suivi; Owner: -; Tablespace: 
--

CREATE TABLE pr_base_visite (
    id integer NOT NULL,
    fk_bs_id integer,
    bv_date date NOT NULL,
    bv_id_table_src integer,
    bv_site_id integer,
    geom public.geometry,
    bv_commentaire character varying(1000),
    bv_ref_commune character varying[],
    meta_numerisateur_id integer,
    meta_create_timestamp date,
    meta_update_timestamp date,
    bv_id_table_src2 integer[]
);


SET search_path = utilisateurs, pg_catalog;

--
-- Name: t_roles_id_seq; Type: SEQUENCE; Schema: utilisateurs; Owner: -
--

CREATE SEQUENCE t_roles_id_seq
    START WITH 1000000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: t_roles; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE t_roles (
    groupe boolean DEFAULT false NOT NULL,
    id_role integer DEFAULT nextval('t_roles_id_seq'::regclass) NOT NULL,
    identifiant character varying(100),
    nom_role character varying(50),
    prenom_role character varying(50),
    desc_role text,
    pass character varying(100),
    email character varying(250),
    id_organisme integer,
    organisme character(32),
    id_unite integer,
    remarques text,
    pn boolean,
    session_appli character varying(50),
    date_insert timestamp without time zone,
    date_update timestamp without time zone
);


SET search_path = chiro, pg_catalog;

--
-- Name: vue_chiro_obs; Type: VIEW; Schema: chiro; Owner: -
--

CREATE VIEW vue_chiro_obs AS
 SELECT obs.id,
    obs.fk_bs_id,
    sit.bs_nom,
    obs.bv_date,
    obs.bv_commentaire,
    obs.bv_id_table_src,
    obs.meta_create_timestamp,
    obs.meta_update_timestamp,
    obs.meta_numerisateur_id,
    ((upper((num.nom_role)::text) || ' '::text) || (num.prenom_role)::text) AS numerisateur,
    array_to_json(obs.bv_ref_commune) AS ref_commune,
    cco.cvc_temperature,
    cco.cvc_humidite,
    cco.cvc_mod_id,
    ( SELECT count(*) AS count
           FROM pr_visite_observationtaxon a
          WHERE (a.fk_bv_id = obs.id)) AS nb_taxons,
    ( SELECT sum(a.cotx_effectif_abs) AS count
           FROM pr_visite_observationtaxon a
          WHERE (a.fk_bv_id = obs.id)) AS abondance
   FROM (((suivi.pr_base_visite obs
     JOIN pr_visite_conditions cco ON ((cco.fk_bv_id = obs.id)))
     JOIN suivi.pr_base_site sit ON ((sit.id = obs.fk_bs_id)))
     LEFT JOIN utilisateurs.t_roles num ON ((num.id_role = obs.meta_numerisateur_id)))
  ORDER BY obs.bv_date DESC;


--
-- Name: vue_chiro_obs_ss_site; Type: VIEW; Schema: chiro; Owner: -
--

CREATE VIEW vue_chiro_obs_ss_site AS
 SELECT obs.id,
    public.st_asgeojson(obs.geom) AS geom,
    obs.bv_date,
    obs.bv_commentaire,
    obs.bv_id_table_src,
    obs.meta_create_timestamp,
    obs.meta_update_timestamp,
    obs.meta_numerisateur_id,
    array_to_json(obs.bv_ref_commune) AS ref_commune,
    ((upper((num.nom_role)::text) || ' '::text) || (num.prenom_role)::text) AS numerisateur,
    cco.cvc_temperature,
    cco.cvc_humidite,
    cco.cvc_mod_id,
    ( SELECT count(*) AS count
           FROM pr_visite_observationtaxon a
          WHERE (a.fk_bv_id = obs.id)) AS nb_taxons,
    ( SELECT sum(a.cotx_effectif_abs) AS count
           FROM pr_visite_observationtaxon a
          WHERE (a.fk_bv_id = obs.id)) AS abondance
   FROM ((suivi.pr_base_visite obs
     JOIN pr_visite_conditions cco ON ((cco.fk_bv_id = obs.id)))
     LEFT JOIN utilisateurs.t_roles num ON ((num.id_role = obs.meta_numerisateur_id)))
  WHERE ((obs.fk_bs_id IS NULL) AND (NOT (obs.geom IS NULL)))
  ORDER BY obs.bv_date DESC;


SET search_path = lexique, pg_catalog;

--
-- Name: t_thesaurus; Type: TABLE; Schema: lexique; Owner: -; Tablespace: 
--

CREATE TABLE t_thesaurus (
    id integer NOT NULL,
    id_type integer,
    code character varying(250),
    libelle character varying(500),
    description character varying,
    fk_parent integer,
    hierarchie character varying(250)
);


SET search_path = suivi, pg_catalog;

--
-- Name: uploads; Type: TABLE; Schema: suivi; Owner: -; Tablespace: 
--

CREATE TABLE uploads (
    id integer NOT NULL,
    path character varying(250)
);


SET search_path = chiro, pg_catalog;

--
-- Name: vue_chiro_site; Type: VIEW; Schema: chiro; Owner: -
--

CREATE VIEW vue_chiro_site AS
 SELECT s.id,
    s.bs_nom,
    s.bs_code,
    s.bs_date,
    s.bs_description,
    s.bs_obr_id,
    s.meta_create_timestamp,
    s.meta_update_timestamp,
    s.meta_numerisateur_id,
    (array_to_json(s.bs_ref_commune))::text AS ref_commune,
    public.st_asgeojson(s.geom) AS geom,
    ((((obr.nom_role)::text || ' '::text) || (obr.prenom_role)::text))::character varying(255) AS nom_observateur,
    s.bs_type_id,
    l.code AS type_lieu,
    c.cis_frequentation,
    c.cis_menace,
    c.cis_menace_cmt,
    c.cis_contact_nom,
    c.cis_contact_prenom,
    c.cis_contact_adresse,
    c.cis_contact_code_postal,
    c.cis_contact_ville,
    c.cis_contact_telephone,
    c.cis_contact_portable,
    c.cis_contact_commentaire,
    c.cis_site_actif,
    c.cis_actions,
    array_to_json(ARRAY( SELECT (((rcf.fichier_id)::text || '_'::text) || (ups.path)::text)
           FROM (rel_chirosite_fichiers rcf
             LEFT JOIN suivi.uploads ups ON ((ups.id = rcf.fichier_id)))
          WHERE (rcf.site_id = s.id))) AS site_fichiers,
    ( SELECT max(obs.bv_date) AS max
           FROM suivi.pr_base_visite obs
          WHERE (obs.fk_bs_id = s.id)) AS dern_obs,
    ( SELECT count(*) AS count
           FROM suivi.pr_base_visite
          WHERE (pr_base_visite.fk_bs_id = s.id)) AS nb_obs
   FROM (((pr_site_infos c
     JOIN suivi.pr_base_site s ON ((c.fk_bs_id = s.id)))
     LEFT JOIN utilisateurs.t_roles obr ON ((obr.id_role = s.bs_obr_id)))
     LEFT JOIN lexique.t_thesaurus l ON ((l.id = s.bs_type_id)))
  ORDER BY s.id;


SET search_path = taxonomie, pg_catalog;

--
-- Name: taxref; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE taxref (
    cd_nom integer NOT NULL,
    id_statut character(1),
    id_habitat integer,
    id_rang character(4),
    regne character varying(20),
    phylum character varying(50),
    classe character varying(50),
    ordre character varying(50),
    famille character varying(50),
    cd_taxsup integer,
    cd_ref integer,
    lb_nom character varying(100),
    lb_auteur character varying(150),
    nom_complet character varying(255),
    nom_valide character varying(255),
    nom_vern character varying(255),
    nom_vern_eng character varying(255),
    group1_inpn character varying(255),
    group2_inpn character varying(255)
);


SET search_path = chiro, pg_catalog;

--
-- Name: vue_chiro_taxref; Type: VIEW; Schema: chiro; Owner: -
--

CREATE VIEW vue_chiro_taxref AS
 SELECT taxref.cd_nom,
    taxref.ordre,
    lower((taxref.nom_complet)::text) AS nom_complet
   FROM taxonomie.taxref
  WHERE ((taxref.ordre)::text = 'Chiroptera'::text);


SET search_path = suivi, pg_catalog;

--
-- Name: rel_obs_obr; Type: TABLE; Schema: suivi; Owner: -; Tablespace: 
--

CREATE TABLE rel_obs_obr (
    obs_id integer NOT NULL,
    obr_id integer NOT NULL
);


SET search_path = chiro, pg_catalog;

--
-- Name: vue_chiro_validation; Type: VIEW; Schema: chiro; Owner: -
--

CREATE VIEW vue_chiro_validation AS
 SELECT tx.id,
    tx.cotx_cd_nom AS cd_nom,
    tx.cotx_nom_complet AS nom_complet,
    tx.cotx_effectif_abs,
    tx.cotx_obj_status_validation,
    tx.cotx_date_validation,
    tx.meta_create_timestamp,
    obs.bv_date,
    site.bs_nom,
    suivi.fct_get_user_name(obs.meta_numerisateur_id) AS numerisateur,
    suivi.fct_get_user_name(tx.cotx_validateur) AS validateur,
    (array_to_json(ARRAY( SELECT suivi.fct_get_user_name(x.obr_id) AS fct_get_user_name
           FROM ( SELECT rel_obs_obr.obr_id
                   FROM suivi.rel_obs_obr
                  WHERE (rel_obs_obr.obs_id = obs.id)) x)))::text AS observateurs,
    public.st_asgeojson(COALESCE(obs.geom, site.geom)) AS geom
   FROM ((pr_visite_observationtaxon tx
     JOIN suivi.pr_base_visite obs ON ((obs.id = tx.fk_bv_id)))
     LEFT JOIN suivi.pr_base_site site ON ((site.id = obs.fk_bs_id)));


SET search_path = utilisateurs, pg_catalog;

--
-- Name: cor_role_menu; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE cor_role_menu (
    id_role integer NOT NULL,
    id_menu integer NOT NULL
);


--
-- Name: TABLE cor_role_menu; Type: COMMENT; Schema: utilisateurs; Owner: -
--

COMMENT ON TABLE cor_role_menu IS 'gestion du contenu des menus utilisateurs dans les applications';


--
-- Name: cor_roles; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE cor_roles (
    id_role_groupe integer NOT NULL,
    id_role_utilisateur integer NOT NULL
);


SET search_path = chiro, pg_catalog;

--
-- Name: vue_utilisateurs_acteurs; Type: VIEW; Schema: chiro; Owner: -
--

CREATE VIEW vue_utilisateurs_acteurs AS
 SELECT DISTINCT r.id_role AS obr_id,
    r.nom_role AS obr_nom,
    r.prenom_role AS obr_prenom,
    ((upper((r.nom_role)::text) || ' '::text) || (r.prenom_role)::text) AS nom_complet,
    lower((((r.nom_role)::text || ' '::text) || (r.prenom_role)::text)) AS nom_complet_lower,
    'observateur'::text AS role
   FROM utilisateurs.t_roles r
  WHERE ((r.id_role IN ( SELECT DISTINCT cr.id_role_utilisateur
           FROM utilisateurs.cor_roles cr
          WHERE (cr.id_role_groupe IN ( SELECT crm.id_role
                   FROM utilisateurs.cor_role_menu crm))
          ORDER BY cr.id_role_utilisateur)) OR (r.id_role IN ( SELECT crm.id_role
           FROM (utilisateurs.cor_role_menu crm
             JOIN utilisateurs.t_roles r_1 ON (((r_1.id_role = crm.id_role) AND (r_1.groupe = false)))))))
UNION
 SELECT DISTINCT r.id_role AS obr_id,
    r.nom_role AS obr_nom,
    r.prenom_role AS obr_prenom,
    ((upper((r.nom_role)::text) || ' '::text) || (r.prenom_role)::text) AS nom_complet,
    lower((((r.nom_role)::text || ' '::text) || (r.prenom_role)::text)) AS nom_complet_lower,
    'validateur'::text AS role
   FROM utilisateurs.t_roles r
  WHERE ((r.id_role IN ( SELECT DISTINCT cr.id_role_utilisateur
           FROM utilisateurs.cor_roles cr
          WHERE (cr.id_role_groupe IN ( SELECT crm.id_role
                   FROM utilisateurs.cor_role_menu crm))
          ORDER BY cr.id_role_utilisateur)) OR (r.id_role IN ( SELECT crm.id_role
           FROM (utilisateurs.cor_role_menu crm
             JOIN utilisateurs.t_roles r_1 ON (((r_1.id_role = crm.id_role) AND (r_1.groupe = false)))))));


SET search_path = lexique, pg_catalog;

--
-- Name: base_application_id_seq; Type: SEQUENCE; Schema: lexique; Owner: -
--

CREATE SEQUENCE base_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lexique_id_seq; Type: SEQUENCE; Schema: lexique; Owner: -
--

CREATE SEQUENCE lexique_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observateur_id_seq; Type: SEQUENCE; Schema: lexique; Owner: -
--

CREATE SEQUENCE observateur_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: t_thesaurus_id_seq; Type: SEQUENCE; Schema: lexique; Owner: -
--

CREATE SEQUENCE t_thesaurus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: t_thesaurus_id_seq; Type: SEQUENCE OWNED BY; Schema: lexique; Owner: -
--

ALTER SEQUENCE t_thesaurus_id_seq OWNED BY t_thesaurus.id;


--
-- Name: taxonomie_id_seq; Type: SEQUENCE; Schema: lexique; Owner: -
--

CREATE SEQUENCE taxonomie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET search_path = ref_geographique, pg_catalog;

--
-- Name: l_communes; Type: TABLE; Schema: ref_geographique; Owner: -; Tablespace: 
--

CREATE TABLE l_communes (
    geom public.geometry(MultiPolygon,2154),
    id_geofla integer,
    code_comm character varying(3),
    code_postal character varying(5),
    insee_com character varying(5),
    nom_comm character varying(50),
    nom_slug character varying,
    nom_simple character varying,
    nom_reel character varying,
    nom_soundex character varying,
    nom_metaphone character varying,
    statut character varying(20),
    x_chf_lieu integer,
    y_chf_lieu integer,
    x_centroid integer,
    y_centroid integer,
    z_moyen integer,
    superficie integer,
    population double precision,
    code_cant character varying(2),
    code_arr character varying(1),
    code_dept character varying(2),
    nom_dept character varying(30),
    code_reg character varying(2),
    nom_region character varying(30),
    unique_code character varying(15)
);


SET search_path = suivi, pg_catalog;

--
-- Name: pr_base_site_id_seq; Type: SEQUENCE; Schema: suivi; Owner: -
--

CREATE SEQUENCE pr_base_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pr_base_site_id_seq; Type: SEQUENCE OWNED BY; Schema: suivi; Owner: -
--

ALTER SEQUENCE pr_base_site_id_seq OWNED BY pr_base_site.id;


--
-- Name: pr_base_visite_id_seq; Type: SEQUENCE; Schema: suivi; Owner: -
--

CREATE SEQUENCE pr_base_visite_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pr_base_visite_id_seq; Type: SEQUENCE OWNED BY; Schema: suivi; Owner: -
--

ALTER SEQUENCE pr_base_visite_id_seq OWNED BY pr_base_visite.id;


--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: suivi; Owner: -
--

CREATE SEQUENCE uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: suivi; Owner: -
--

ALTER SEQUENCE uploads_id_seq OWNED BY uploads.id;


SET search_path = taxonomie, pg_catalog;

--
-- Name: bib_groupes; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE bib_groupes (
    id_groupe integer NOT NULL,
    nom_groupe character varying(255),
    desc_groupe text,
    filtre_sql text
);


--
-- Name: bib_taxons; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE bib_taxons (
    id_taxon integer NOT NULL,
    cd_nom integer,
    nom_latin character varying(100),
    nom_francais character varying(255),
    auteur character varying(200),
    saisie_autorisee integer,
    id_groupe integer,
    patrimonial boolean DEFAULT false NOT NULL,
    protection_stricte boolean
);


--
-- Name: bib_taxref_habitats; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE bib_taxref_habitats (
    id_habitat integer NOT NULL,
    nom_habitat character varying(50) NOT NULL
);


--
-- Name: bib_taxref_rangs; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE bib_taxref_rangs (
    id_rang character(4) NOT NULL,
    nom_rang character varying(20) NOT NULL
);


--
-- Name: bib_taxref_statuts; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE bib_taxref_statuts (
    id_statut character(1) NOT NULL,
    nom_statut character varying(50) NOT NULL
);


--
-- Name: import_taxref; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE import_taxref (
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
    nom_valide character varying(255),
    nom_vern character varying(500),
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
    url text
);


--
-- Name: taxref_changes; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE taxref_changes (
    cd_nom integer NOT NULL,
    num_version_init character varying(5),
    num_version_final character varying(5),
    champ character varying(50) NOT NULL,
    valeur_init character varying(255),
    valeur_final character varying(255),
    type_change character varying(25)
);


--
-- Name: taxref_protection_articles; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE taxref_protection_articles (
    cd_protection character varying(20) NOT NULL,
    article character varying(100),
    intitule text,
    protection text,
    arrete text,
    fichier text,
    fg_afprot integer,
    niveau character varying(250),
    cd_arrete integer,
    url character varying(250),
    date_arrete integer,
    rang_niveau integer,
    lb_article text,
    type_protection character varying(250),
    pn boolean
);


--
-- Name: taxref_protection_especes; Type: TABLE; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE TABLE taxref_protection_especes (
    cd_nom integer NOT NULL,
    cd_protection character varying(20) NOT NULL,
    nom_cite character varying(200),
    syn_cite character varying(200),
    nom_francais_cite character varying(100),
    precisions text,
    cd_nom_cite character varying(255) NOT NULL
);


SET search_path = utilisateurs, pg_catalog;

--
-- Name: bib_droits; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE bib_droits (
    id_droit integer NOT NULL,
    nom_droit character varying(50),
    desc_droit text
);


--
-- Name: bib_observateurs; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE bib_observateurs (
    codeobs character varying(6) NOT NULL,
    nom character varying(100),
    prenom character varying(100),
    orphelin integer
);


--
-- Name: bib_organismes_id_seq; Type: SEQUENCE; Schema: utilisateurs; Owner: -
--

CREATE SEQUENCE bib_organismes_id_seq
    START WITH 1000000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bib_organismes; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE bib_organismes (
    nom_organisme character varying(100) NOT NULL,
    adresse_organisme character varying(128),
    cp_organisme character varying(5),
    ville_organisme character varying(100),
    tel_organisme character varying(14),
    fax_organisme character varying(14),
    email_organisme character varying(100),
    id_organisme integer DEFAULT nextval('bib_organismes_id_seq'::regclass) NOT NULL
);


--
-- Name: bib_unites_id_seq; Type: SEQUENCE; Schema: utilisateurs; Owner: -
--

CREATE SEQUENCE bib_unites_id_seq
    START WITH 1000000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bib_unites; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE bib_unites (
    nom_unite character varying(50) NOT NULL,
    adresse_unite character varying(128),
    cp_unite character varying(5),
    ville_unite character varying(100),
    tel_unite character varying(14),
    fax_unite character varying(14),
    email_unite character varying(100),
    id_unite integer DEFAULT nextval('bib_unites_id_seq'::regclass) NOT NULL
);


--
-- Name: cor_role_droit_application; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE cor_role_droit_application (
    id_role integer NOT NULL,
    id_droit integer NOT NULL,
    id_application integer NOT NULL
);


--
-- Name: t_applications; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE t_applications (
    id_application integer NOT NULL,
    nom_application character varying(50) NOT NULL,
    desc_application text
);


--
-- Name: t_applications_id_application_seq; Type: SEQUENCE; Schema: utilisateurs; Owner: -
--

CREATE SEQUENCE t_applications_id_application_seq
    START WITH 1000000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: t_applications_id_application_seq; Type: SEQUENCE OWNED BY; Schema: utilisateurs; Owner: -
--

ALTER SEQUENCE t_applications_id_application_seq OWNED BY t_applications.id_application;


--
-- Name: t_menus; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE t_menus (
    id_menu integer NOT NULL,
    nom_menu character varying(50) NOT NULL,
    desc_menu text,
    id_application integer
);


--
-- Name: TABLE t_menus; Type: COMMENT; Schema: utilisateurs; Owner: -
--

COMMENT ON TABLE t_menus IS 'table des menus déroulants des applications. Les roles de niveau groupes ou utilisateurs devant figurer dans un menu sont gérés dans la table cor_role_menu_application.';


--
-- Name: t_menus_id_menu_seq; Type: SEQUENCE; Schema: utilisateurs; Owner: -
--

CREATE SEQUENCE t_menus_id_menu_seq
    START WITH 1000000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: t_menus_id_menu_seq; Type: SEQUENCE OWNED BY; Schema: utilisateurs; Owner: -
--

ALTER SEQUENCE t_menus_id_menu_seq OWNED BY t_menus.id_menu;


--
-- Name: tmp_obs_occ_personne; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE tmp_obs_occ_personne (
    id_personne integer,
    remarque text,
    fax text,
    portable text,
    tel_pro text,
    tel_perso text,
    pays text,
    ville text,
    code_postal text,
    adresse_1 text,
    prenom text NOT NULL,
    nom text NOT NULL,
    email text,
    role text,
    specialite text,
    mot_de_passe text DEFAULT 0 NOT NULL,
    createur integer,
    titre text,
    date_maj text
);


--
-- Name: tmp_pnc_personne; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE tmp_pnc_personne (
    id integer,
    id_obs_occ integer,
    id_point_ecoute integer,
    id_saisie_km integer,
    id_db_pnc integer,
    prenom text,
    nom text,
    email text,
    mot_de_passe text,
    obr_parc boolean,
    saisie_flore boolean,
    saisie_eau boolean,
    code character varying(250)
);


--
-- Name: view_login; Type: TABLE; Schema: utilisateurs; Owner: -; Tablespace: 
--

CREATE TABLE view_login (
    id_role integer,
    identifiant character varying(100),
    pass character varying(100),
    nom_complet text,
    id_application integer,
    maxdroit integer
);


SET search_path = chiro, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY pr_site_infos ALTER COLUMN id SET DEFAULT nextval('pr_site_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY pr_visite_conditions ALTER COLUMN id SET DEFAULT nextval('pr_visite_conditions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY pr_visite_observationtaxon ALTER COLUMN id SET DEFAULT nextval('pr_visite_observationtaxon_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY subpr_observationtaxon_biometrie ALTER COLUMN id SET DEFAULT nextval('subpr_observationtaxon_biometrie_id_seq'::regclass);


SET search_path = lexique, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: lexique; Owner: -
--

ALTER TABLE ONLY t_thesaurus ALTER COLUMN id SET DEFAULT nextval('t_thesaurus_id_seq'::regclass);


SET search_path = suivi, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: suivi; Owner: -
--

ALTER TABLE ONLY pr_base_site ALTER COLUMN id SET DEFAULT nextval('pr_base_site_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: suivi; Owner: -
--

ALTER TABLE ONLY pr_base_visite ALTER COLUMN id SET DEFAULT nextval('pr_base_visite_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: suivi; Owner: -
--

ALTER TABLE ONLY uploads ALTER COLUMN id SET DEFAULT nextval('uploads_id_seq'::regclass);


SET search_path = utilisateurs, pg_catalog;

--
-- Name: id_application; Type: DEFAULT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY t_applications ALTER COLUMN id_application SET DEFAULT nextval('t_applications_id_application_seq'::regclass);


--
-- Name: id_menu; Type: DEFAULT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY t_menus ALTER COLUMN id_menu SET DEFAULT nextval('t_menus_id_menu_seq'::regclass);


SET search_path = chiro, pg_catalog;

--
-- Name: cbio_pkey; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY subpr_observationtaxon_biometrie
    ADD CONSTRAINT cbio_pkey PRIMARY KEY (id);


--
-- Name: cis_pk; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pr_site_infos
    ADD CONSTRAINT cis_pk PRIMARY KEY (id);


--
-- Name: cotx_pkey; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pr_visite_observationtaxon
    ADD CONSTRAINT cotx_pkey PRIMARY KEY (id);


--
-- Name: cvc_pkey; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pr_visite_conditions
    ADD CONSTRAINT cvc_pkey PRIMARY KEY (id);


--
-- Name: pk_amenagement_f; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rel_chirosite_thesaurus_amenagement
    ADD CONSTRAINT pk_amenagement_f PRIMARY KEY (site_id, thesaurus_id);


--
-- Name: pk_cotx_f; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rel_observationtaxon_fichiers
    ADD CONSTRAINT pk_cotx_f PRIMARY KEY (cotx_id, fichier_id);


--
-- Name: pk_cs_f; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rel_chirosite_fichiers
    ADD CONSTRAINT pk_cs_f PRIMARY KEY (site_id, fichier_id);


--
-- Name: pk_indices_i; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rel_observationtaxon_thesaurus_indice
    ADD CONSTRAINT pk_indices_i PRIMARY KEY (cotx_id, thesaurus_id);


--
-- Name: pk_menace_f; Type: CONSTRAINT; Schema: chiro; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rel_chirosite_thesaurus_menace
    ADD CONSTRAINT pk_menace_f PRIMARY KEY (site_id, thesaurus_id);


SET search_path = lexique, pg_catalog;

--
-- Name: tthesaurus_pkey; Type: CONSTRAINT; Schema: lexique; Owner: -; Tablespace: 
--

ALTER TABLE ONLY t_thesaurus
    ADD CONSTRAINT tthesaurus_pkey PRIMARY KEY (id);


SET search_path = suivi, pg_catalog;

--
-- Name: bs_pkey; Type: CONSTRAINT; Schema: suivi; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pr_base_site
    ADD CONSTRAINT bs_pkey PRIMARY KEY (id);


--
-- Name: bv_pkey; Type: CONSTRAINT; Schema: suivi; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pr_base_visite
    ADD CONSTRAINT bv_pkey PRIMARY KEY (id);


--
-- Name: obs_obr_pk; Type: CONSTRAINT; Schema: suivi; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rel_obs_obr
    ADD CONSTRAINT obs_obr_pk PRIMARY KEY (obs_id, obr_id);


--
-- Name: upload_pk; Type: CONSTRAINT; Schema: suivi; Owner: -; Tablespace: 
--

ALTER TABLE ONLY uploads
    ADD CONSTRAINT upload_pk PRIMARY KEY (id);


SET search_path = taxonomie, pg_catalog;

--
-- Name: pk_bib_groupe; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_groupes
    ADD CONSTRAINT pk_bib_groupe PRIMARY KEY (id_groupe);


--
-- Name: pk_bib_taxons; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_taxons
    ADD CONSTRAINT pk_bib_taxons PRIMARY KEY (id_taxon);


--
-- Name: pk_bib_taxref_habitats; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_taxref_habitats
    ADD CONSTRAINT pk_bib_taxref_habitats PRIMARY KEY (id_habitat);


--
-- Name: pk_bib_taxref_rangs; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_taxref_rangs
    ADD CONSTRAINT pk_bib_taxref_rangs PRIMARY KEY (id_rang);


--
-- Name: pk_bib_taxref_statuts; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_taxref_statuts
    ADD CONSTRAINT pk_bib_taxref_statuts PRIMARY KEY (id_statut);


--
-- Name: pk_import_taxref; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY import_taxref
    ADD CONSTRAINT pk_import_taxref PRIMARY KEY (cd_nom);


--
-- Name: pk_taxref; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taxref
    ADD CONSTRAINT pk_taxref PRIMARY KEY (cd_nom);


--
-- Name: pk_taxref_changes; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taxref_changes
    ADD CONSTRAINT pk_taxref_changes PRIMARY KEY (cd_nom, champ);


--
-- Name: taxref_protection_articles_pkey; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taxref_protection_articles
    ADD CONSTRAINT taxref_protection_articles_pkey PRIMARY KEY (cd_protection);


--
-- Name: taxref_protection_especes_pkey; Type: CONSTRAINT; Schema: taxonomie; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taxref_protection_especes
    ADD CONSTRAINT taxref_protection_especes_pkey PRIMARY KEY (cd_nom, cd_protection, cd_nom_cite);


SET search_path = utilisateurs, pg_catalog;

--
-- Name: bib_droits_pkey; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_droits
    ADD CONSTRAINT bib_droits_pkey PRIMARY KEY (id_droit);


--
-- Name: bib_observateurs_pk; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_observateurs
    ADD CONSTRAINT bib_observateurs_pk PRIMARY KEY (codeobs);


--
-- Name: cor_role_droit_application_pkey; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cor_role_droit_application
    ADD CONSTRAINT cor_role_droit_application_pkey PRIMARY KEY (id_role, id_droit, id_application);


--
-- Name: cor_role_menu_pkey; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cor_role_menu
    ADD CONSTRAINT cor_role_menu_pkey PRIMARY KEY (id_role, id_menu);


--
-- Name: cor_roles_pkey; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cor_roles
    ADD CONSTRAINT cor_roles_pkey PRIMARY KEY (id_role_groupe, id_role_utilisateur);


--
-- Name: pk_bib_organismes; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_organismes
    ADD CONSTRAINT pk_bib_organismes PRIMARY KEY (id_organisme);


--
-- Name: pk_bib_services; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bib_unites
    ADD CONSTRAINT pk_bib_services PRIMARY KEY (id_unite);


--
-- Name: pk_roles; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY t_roles
    ADD CONSTRAINT pk_roles PRIMARY KEY (id_role);


--
-- Name: t_applications_pkey; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY t_applications
    ADD CONSTRAINT t_applications_pkey PRIMARY KEY (id_application);


--
-- Name: t_menus_pkey; Type: CONSTRAINT; Schema: utilisateurs; Owner: -; Tablespace: 
--

ALTER TABLE ONLY t_menus
    ADD CONSTRAINT t_menus_pkey PRIMARY KEY (id_menu);


SET search_path = chiro, pg_catalog;

--
-- Name: idx_291ed261ec9c5fd7; Type: INDEX; Schema: chiro; Owner: -; Tablespace: 
--

CREATE INDEX idx_291ed261ec9c5fd7 ON subpr_observationtaxon_biometrie USING btree (fk_cotx_id);


--
-- Name: idx_5e796d2c4b182b51; Type: INDEX; Schema: chiro; Owner: -; Tablespace: 
--

CREATE INDEX idx_5e796d2c4b182b51 ON pr_visite_observationtaxon USING btree (fk_bv_id);


--
-- Name: uniq_49ec129cf6bd1646; Type: INDEX; Schema: chiro; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX uniq_49ec129cf6bd1646 ON pr_site_infos USING btree (fk_bs_id);


--
-- Name: uniq_95658e144b182b51; Type: INDEX; Schema: chiro; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX uniq_95658e144b182b51 ON pr_visite_conditions USING btree (fk_bv_id);


SET search_path = ref_geographique, pg_catalog;

--
-- Name: sidx_communes_france_geom; Type: INDEX; Schema: ref_geographique; Owner: -; Tablespace: 
--

CREATE INDEX sidx_communes_france_geom ON l_communes USING gist (geom);


SET search_path = suivi, pg_catalog;

--
-- Name: geomidx; Type: INDEX; Schema: suivi; Owner: -; Tablespace: 
--

CREATE INDEX geomidx ON pr_base_site USING gist (geom);


--
-- Name: idx_7dc4f50cf6bd1646; Type: INDEX; Schema: suivi; Owner: -; Tablespace: 
--

CREATE INDEX idx_7dc4f50cf6bd1646 ON pr_base_visite USING btree (fk_bs_id);


--
-- Name: idx_f56895f053547af7; Type: INDEX; Schema: suivi; Owner: -; Tablespace: 
--

CREATE INDEX idx_f56895f053547af7 ON pr_base_site USING btree (bs_obr_id);


--
-- Name: idx_f56895f0c54c8c93; Type: INDEX; Schema: suivi; Owner: -; Tablespace: 
--

CREATE INDEX idx_f56895f0c54c8c93 ON pr_base_site USING btree (bs_type_id);


SET search_path = taxonomie, pg_catalog;

--
-- Name: fki_bib_taxons_bib_groupes; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX fki_bib_taxons_bib_groupes ON bib_taxons USING btree (id_groupe);


--
-- Name: fki_cd_nom_taxref_protection_especes; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX fki_cd_nom_taxref_protection_especes ON taxref_protection_especes USING btree (cd_nom);


--
-- Name: i_fk_bib_taxons_taxr; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_fk_bib_taxons_taxr ON bib_taxons USING btree (cd_nom);


--
-- Name: i_fk_taxref_bib_taxref_habitat; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_fk_taxref_bib_taxref_habitat ON taxref USING btree (id_habitat);


--
-- Name: i_fk_taxref_bib_taxref_rangs; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_fk_taxref_bib_taxref_rangs ON taxref USING btree (id_rang);


--
-- Name: i_fk_taxref_bib_taxref_statuts; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_fk_taxref_bib_taxref_statuts ON taxref USING btree (id_statut);


--
-- Name: i_taxref_cd_nom; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_taxref_cd_nom ON taxref USING btree (cd_nom);


--
-- Name: i_taxref_cd_ref; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_taxref_cd_ref ON taxref USING btree (cd_ref);


--
-- Name: i_taxref_hierarchy; Type: INDEX; Schema: taxonomie; Owner: -; Tablespace: 
--

CREATE INDEX i_taxref_hierarchy ON taxref USING btree (regne, phylum, classe, ordre, famille);


SET search_path = utilisateurs, pg_catalog;

--
-- Name: _RETURN; Type: RULE; Schema: utilisateurs; Owner: -
--

CREATE RULE "_RETURN" AS
    ON SELECT TO view_login DO INSTEAD  SELECT tr.id_role,
    tr.identifiant,
    tr.pass,
    (((tr.nom_role)::text || ' '::text) || (tr.prenom_role)::text) AS nom_complet,
    crda.id_application,
    max(crda.id_droit) AS maxdroit
   FROM ((t_roles tr
     JOIN cor_roles cr ON ((cr.id_role_utilisateur = tr.id_role)))
     JOIN cor_role_droit_application crda ON (((crda.id_role = tr.id_role) OR (crda.id_role = cr.id_role_groupe))))
  GROUP BY tr.id_role, crda.id_application;


SET search_path = chiro, pg_catalog;

--
-- Name: trg_date_changes; Type: TRIGGER; Schema: chiro; Owner: -
--

CREATE TRIGGER trg_date_changes BEFORE INSERT OR UPDATE ON pr_visite_observationtaxon FOR EACH ROW EXECUTE PROCEDURE suivi.fct_trg_date_changes();


--
-- Name: trg_date_changes; Type: TRIGGER; Schema: chiro; Owner: -
--

CREATE TRIGGER trg_date_changes BEFORE INSERT OR UPDATE ON subpr_observationtaxon_biometrie FOR EACH ROW EXECUTE PROCEDURE suivi.fct_trg_date_changes();


SET search_path = suivi, pg_catalog;

--
-- Name: trg_add_obs_geom; Type: TRIGGER; Schema: suivi; Owner: -
--

CREATE TRIGGER trg_add_obs_geom BEFORE INSERT OR UPDATE ON pr_base_visite FOR EACH ROW EXECUTE PROCEDURE fct_trg_add_obs_geom();


--
-- Name: trg_commune_from_geom; Type: TRIGGER; Schema: suivi; Owner: -
--

CREATE TRIGGER trg_commune_from_geom BEFORE INSERT OR UPDATE ON pr_base_visite FOR EACH ROW EXECUTE PROCEDURE fct_trg_commune_from_geom();


--
-- Name: trg_commune_from_geom; Type: TRIGGER; Schema: suivi; Owner: -
--

CREATE TRIGGER trg_commune_from_geom BEFORE INSERT OR UPDATE ON pr_base_site FOR EACH ROW EXECUTE PROCEDURE fct_trg_commune_from_geom();


--
-- Name: trg_date_changes; Type: TRIGGER; Schema: suivi; Owner: -
--

CREATE TRIGGER trg_date_changes BEFORE INSERT OR UPDATE ON pr_base_site FOR EACH ROW EXECUTE PROCEDURE fct_trg_date_changes();


--
-- Name: trg_date_changes; Type: TRIGGER; Schema: suivi; Owner: -
--

CREATE TRIGGER trg_date_changes BEFORE INSERT OR UPDATE ON pr_base_visite FOR EACH ROW EXECUTE PROCEDURE fct_trg_date_changes();


--
-- Name: trg_gen_bs_code; Type: TRIGGER; Schema: suivi; Owner: -
--

CREATE TRIGGER trg_gen_bs_code BEFORE INSERT OR UPDATE ON pr_base_site FOR EACH ROW EXECUTE PROCEDURE fct_trg_gen_bs_code();


SET search_path = utilisateurs, pg_catalog;

--
-- Name: modify_date_insert_trigger; Type: TRIGGER; Schema: utilisateurs; Owner: -
--

CREATE TRIGGER modify_date_insert_trigger BEFORE INSERT ON t_roles FOR EACH ROW EXECUTE PROCEDURE modify_date_insert();


--
-- Name: modify_date_update_trigger; Type: TRIGGER; Schema: utilisateurs; Owner: -
--

CREATE TRIGGER modify_date_update_trigger BEFORE UPDATE ON t_roles FOR EACH ROW EXECUTE PROCEDURE modify_date_update();


SET search_path = chiro, pg_catalog;

--
-- Name: fk_bs; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY pr_site_infos
    ADD CONSTRAINT fk_bs FOREIGN KEY (fk_bs_id) REFERENCES suivi.pr_base_site(id) ON DELETE CASCADE;


--
-- Name: fk_bv; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY pr_visite_conditions
    ADD CONSTRAINT fk_bv FOREIGN KEY (fk_bv_id) REFERENCES suivi.pr_base_visite(id);


--
-- Name: fk_bv; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY pr_visite_observationtaxon
    ADD CONSTRAINT fk_bv FOREIGN KEY (fk_bv_id) REFERENCES suivi.pr_base_visite(id);


--
-- Name: fk_chirosite; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_chirosite_fichiers
    ADD CONSTRAINT fk_chirosite FOREIGN KEY (site_id) REFERENCES suivi.pr_base_site(id) ON DELETE CASCADE;


--
-- Name: fk_chirosite_amenagement; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_chirosite_thesaurus_amenagement
    ADD CONSTRAINT fk_chirosite_amenagement FOREIGN KEY (site_id) REFERENCES suivi.pr_base_site(id) ON DELETE CASCADE;


--
-- Name: fk_chirosite_menace; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_chirosite_thesaurus_menace
    ADD CONSTRAINT fk_chirosite_menace FOREIGN KEY (site_id) REFERENCES suivi.pr_base_site(id) ON DELETE CASCADE;


--
-- Name: fk_cotx; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY subpr_observationtaxon_biometrie
    ADD CONSTRAINT fk_cotx FOREIGN KEY (fk_cotx_id) REFERENCES pr_visite_observationtaxon(id);


--
-- Name: fk_observationtaxon; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_observationtaxon_fichiers
    ADD CONSTRAINT fk_observationtaxon FOREIGN KEY (cotx_id) REFERENCES pr_visite_observationtaxon(id) ON DELETE CASCADE;


--
-- Name: fk_observationtaxon_indice; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_observationtaxon_thesaurus_indice
    ADD CONSTRAINT fk_observationtaxon_indice FOREIGN KEY (cotx_id) REFERENCES pr_visite_observationtaxon(id) ON DELETE CASCADE;


--
-- Name: fk_thesaurus_amenagement; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_chirosite_thesaurus_amenagement
    ADD CONSTRAINT fk_thesaurus_amenagement FOREIGN KEY (thesaurus_id) REFERENCES lexique.t_thesaurus(id) ON DELETE CASCADE;


--
-- Name: fk_thesaurus_indice; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_observationtaxon_thesaurus_indice
    ADD CONSTRAINT fk_thesaurus_indice FOREIGN KEY (thesaurus_id) REFERENCES lexique.t_thesaurus(id) ON DELETE CASCADE;


--
-- Name: fk_thesaurus_menace; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_chirosite_thesaurus_menace
    ADD CONSTRAINT fk_thesaurus_menace FOREIGN KEY (thesaurus_id) REFERENCES lexique.t_thesaurus(id) ON DELETE CASCADE;


--
-- Name: fk_uploads; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_chirosite_fichiers
    ADD CONSTRAINT fk_uploads FOREIGN KEY (fichier_id) REFERENCES suivi.uploads(id) ON DELETE CASCADE;


--
-- Name: fk_uploads; Type: FK CONSTRAINT; Schema: chiro; Owner: -
--

ALTER TABLE ONLY rel_observationtaxon_fichiers
    ADD CONSTRAINT fk_uploads FOREIGN KEY (fichier_id) REFERENCES suivi.uploads(id) ON DELETE CASCADE;


SET search_path = suivi, pg_catalog;

--
-- Name: fk_7dc4f50cf6bd1646; Type: FK CONSTRAINT; Schema: suivi; Owner: -
--

ALTER TABLE ONLY pr_base_visite
    ADD CONSTRAINT fk_7dc4f50cf6bd1646 FOREIGN KEY (fk_bs_id) REFERENCES pr_base_site(id);


--
-- Name: obs_id; Type: FK CONSTRAINT; Schema: suivi; Owner: -
--

ALTER TABLE ONLY rel_obs_obr
    ADD CONSTRAINT obs_id FOREIGN KEY (obs_id) REFERENCES pr_base_visite(id);


SET search_path = taxonomie, pg_catalog;

--
-- Name: bib_taxons_id_groupe_fkey; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY bib_taxons
    ADD CONSTRAINT bib_taxons_id_groupe_fkey FOREIGN KEY (id_groupe) REFERENCES bib_groupes(id_groupe) ON UPDATE CASCADE;


--
-- Name: fk_bib_taxons_taxref; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY bib_taxons
    ADD CONSTRAINT fk_bib_taxons_taxref FOREIGN KEY (cd_nom) REFERENCES taxref(cd_nom);


--
-- Name: fk_taxref_bib_taxref_habitats; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY taxref
    ADD CONSTRAINT fk_taxref_bib_taxref_habitats FOREIGN KEY (id_habitat) REFERENCES bib_taxref_habitats(id_habitat) ON UPDATE CASCADE;


--
-- Name: fk_taxref_bib_taxref_rangs; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY taxref
    ADD CONSTRAINT fk_taxref_bib_taxref_rangs FOREIGN KEY (id_rang) REFERENCES bib_taxref_rangs(id_rang) ON UPDATE CASCADE;


--
-- Name: taxref_id_statut_fkey; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY taxref
    ADD CONSTRAINT taxref_id_statut_fkey FOREIGN KEY (id_statut) REFERENCES bib_taxref_statuts(id_statut) ON UPDATE CASCADE;


--
-- Name: taxref_protection_especes_cd_nom_fkey; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY taxref_protection_especes
    ADD CONSTRAINT taxref_protection_especes_cd_nom_fkey FOREIGN KEY (cd_nom) REFERENCES taxref(cd_nom) ON UPDATE CASCADE;


--
-- Name: taxref_protection_especes_cd_protection_fkey; Type: FK CONSTRAINT; Schema: taxonomie; Owner: -
--

ALTER TABLE ONLY taxref_protection_especes
    ADD CONSTRAINT taxref_protection_especes_cd_protection_fkey FOREIGN KEY (cd_protection) REFERENCES taxref_protection_articles(cd_protection);


SET search_path = utilisateurs, pg_catalog;

--
-- Name: cor_role_droit_application_id_application_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_role_droit_application
    ADD CONSTRAINT cor_role_droit_application_id_application_fkey FOREIGN KEY (id_application) REFERENCES t_applications(id_application) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cor_role_droit_application_id_droit_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_role_droit_application
    ADD CONSTRAINT cor_role_droit_application_id_droit_fkey FOREIGN KEY (id_droit) REFERENCES bib_droits(id_droit) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cor_role_droit_application_id_role_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_role_droit_application
    ADD CONSTRAINT cor_role_droit_application_id_role_fkey FOREIGN KEY (id_role) REFERENCES t_roles(id_role) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cor_role_menu_application_id_menu_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_role_menu
    ADD CONSTRAINT cor_role_menu_application_id_menu_fkey FOREIGN KEY (id_menu) REFERENCES t_menus(id_menu) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cor_role_menu_application_id_role_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_role_menu
    ADD CONSTRAINT cor_role_menu_application_id_role_fkey FOREIGN KEY (id_role) REFERENCES t_roles(id_role) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cor_roles_id_role_groupe_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_roles
    ADD CONSTRAINT cor_roles_id_role_groupe_fkey FOREIGN KEY (id_role_groupe) REFERENCES t_roles(id_role) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cor_roles_id_role_utilisateur_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY cor_roles
    ADD CONSTRAINT cor_roles_id_role_utilisateur_fkey FOREIGN KEY (id_role_utilisateur) REFERENCES t_roles(id_role) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: t_menus_id_application_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY t_menus
    ADD CONSTRAINT t_menus_id_application_fkey FOREIGN KEY (id_application) REFERENCES t_applications(id_application) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: t_roles_id_organisme_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY t_roles
    ADD CONSTRAINT t_roles_id_organisme_fkey FOREIGN KEY (id_organisme) REFERENCES bib_organismes(id_organisme) ON UPDATE CASCADE;


--
-- Name: t_roles_id_unite_fkey; Type: FK CONSTRAINT; Schema: utilisateurs; Owner: -
--

ALTER TABLE ONLY t_roles
    ADD CONSTRAINT t_roles_id_unite_fkey FOREIGN KEY (id_unite) REFERENCES bib_unites(id_unite) ON UPDATE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

