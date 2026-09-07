SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: block_consent_certificate_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.block_consent_certificate_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'consent_certificates rows are immutable (attempted % on id=%)', TG_OP, OLD.id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    account_id character varying NOT NULL,
    company_name character varying NOT NULL,
    plan character varying DEFAULT 'starter'::character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    monthly_credit_allowance integer DEFAULT 0 NOT NULL,
    credits_used_this_cycle integer DEFAULT 0 NOT NULL,
    cycle_start date,
    cycle_end date,
    avg_daily_burn integer DEFAULT 0,
    billing_contact character varying,
    enabled_modules character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: activity_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_events (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    lead_id bigint,
    verification_run_id bigint,
    event_type character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: activity_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_events_id_seq OWNED BY public.activity_events.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: capture_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capture_sessions (
    id bigint NOT NULL,
    pixel_id bigint NOT NULL,
    account_id bigint NOT NULL,
    session_id character varying NOT NULL,
    page_url character varying,
    referrer character varying,
    user_agent character varying,
    visit_ip character varying,
    started_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: capture_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.capture_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: capture_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.capture_sessions_id_seq OWNED BY public.capture_sessions.id;


--
-- Name: consensus_verdicts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consensus_verdicts (
    id bigint NOT NULL,
    verification_run_id bigint NOT NULL,
    account_id bigint NOT NULL,
    policy_version_id bigint NOT NULL,
    verdict character varying NOT NULL,
    score double precision,
    reasons jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: consensus_verdicts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.consensus_verdicts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: consensus_verdicts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.consensus_verdicts_id_seq OWNED BY public.consensus_verdicts.id;


--
-- Name: consent_certificates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consent_certificates (
    id bigint NOT NULL,
    lead_id bigint NOT NULL,
    verification_run_id bigint NOT NULL,
    account_id bigint NOT NULL,
    certificate_uid character varying NOT NULL,
    content_hash character varying NOT NULL,
    trusted_form_cert_url character varying,
    issued_at timestamp(6) without time zone NOT NULL,
    snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    previous_hash character varying,
    sequence_number integer NOT NULL
);


--
-- Name: consent_certificates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.consent_certificates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: consent_certificates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.consent_certificates_id_seq OWNED BY public.consent_certificates.id;


--
-- Name: credit_ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_ledger_entries (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    verification_run_id bigint,
    layer character varying,
    delta integer NOT NULL,
    reason character varying NOT NULL,
    balance_after integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: credit_ledger_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_ledger_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_ledger_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_ledger_entries_id_seq OWNED BY public.credit_ledger_entries.id;


--
-- Name: crm_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crm_contacts (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    external_crm_id character varying NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    phone character varying,
    crm_created_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: crm_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crm_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crm_contacts_id_seq OWNED BY public.crm_contacts.id;


--
-- Name: layer_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.layer_results (
    id bigint NOT NULL,
    verification_run_id bigint NOT NULL,
    account_id bigint NOT NULL,
    layer character varying NOT NULL,
    state character varying NOT NULL,
    raw_response jsonb DEFAULT '{}'::jsonb NOT NULL,
    credits_charged integer DEFAULT 0 NOT NULL,
    evaluated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: layer_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.layer_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: layer_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.layer_results_id_seq OWNED BY public.layer_results.id;


--
-- Name: leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leads (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    pixel_id bigint NOT NULL,
    capture_session_id bigint,
    lead_id character varying NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    phone character varying,
    submit_ip character varying,
    landing_page_url character varying,
    campaign character varying,
    trusted_form_cert_url character varying,
    form_dwell_ms integer,
    submitted_at timestamp(6) without time zone NOT NULL,
    raw_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    activity_token character varying,
    activity_token_expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: leads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.leads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: leads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.leads_id_seq OWNED BY public.leads.id;


--
-- Name: module_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.module_costs (
    id bigint NOT NULL,
    layer character varying NOT NULL,
    cost_in_credits integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: module_costs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.module_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: module_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.module_costs_id_seq OWNED BY public.module_costs.id;


--
-- Name: pixels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pixels (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    public_id character varying NOT NULL,
    name character varying NOT NULL,
    allowed_landing_pages character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pixels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pixels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pixels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pixels_id_seq OWNED BY public.pixels.id;


--
-- Name: policy_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.policy_versions (
    id bigint NOT NULL,
    account_id bigint,
    name character varying NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: policy_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.policy_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: policy_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.policy_versions_id_seq OWNED BY public.policy_versions.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    account_id bigint,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: verification_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verification_runs (
    id bigint NOT NULL,
    lead_id bigint NOT NULL,
    account_id bigint NOT NULL,
    policy_version_id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: verification_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.verification_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: verification_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.verification_runs_id_seq OWNED BY public.verification_runs.id;


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: activity_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_events ALTER COLUMN id SET DEFAULT nextval('public.activity_events_id_seq'::regclass);


--
-- Name: capture_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capture_sessions ALTER COLUMN id SET DEFAULT nextval('public.capture_sessions_id_seq'::regclass);


--
-- Name: consensus_verdicts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consensus_verdicts ALTER COLUMN id SET DEFAULT nextval('public.consensus_verdicts_id_seq'::regclass);


--
-- Name: consent_certificates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_certificates ALTER COLUMN id SET DEFAULT nextval('public.consent_certificates_id_seq'::regclass);


--
-- Name: credit_ledger_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_ledger_entries ALTER COLUMN id SET DEFAULT nextval('public.credit_ledger_entries_id_seq'::regclass);


--
-- Name: crm_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crm_contacts ALTER COLUMN id SET DEFAULT nextval('public.crm_contacts_id_seq'::regclass);


--
-- Name: layer_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_results ALTER COLUMN id SET DEFAULT nextval('public.layer_results_id_seq'::regclass);


--
-- Name: leads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads ALTER COLUMN id SET DEFAULT nextval('public.leads_id_seq'::regclass);


--
-- Name: module_costs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.module_costs ALTER COLUMN id SET DEFAULT nextval('public.module_costs_id_seq'::regclass);


--
-- Name: pixels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pixels ALTER COLUMN id SET DEFAULT nextval('public.pixels_id_seq'::regclass);


--
-- Name: policy_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_versions ALTER COLUMN id SET DEFAULT nextval('public.policy_versions_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: verification_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_runs ALTER COLUMN id SET DEFAULT nextval('public.verification_runs_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: activity_events activity_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_events
    ADD CONSTRAINT activity_events_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: capture_sessions capture_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capture_sessions
    ADD CONSTRAINT capture_sessions_pkey PRIMARY KEY (id);


--
-- Name: consensus_verdicts consensus_verdicts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consensus_verdicts
    ADD CONSTRAINT consensus_verdicts_pkey PRIMARY KEY (id);


--
-- Name: consent_certificates consent_certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_certificates
    ADD CONSTRAINT consent_certificates_pkey PRIMARY KEY (id);


--
-- Name: credit_ledger_entries credit_ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_ledger_entries
    ADD CONSTRAINT credit_ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: crm_contacts crm_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crm_contacts
    ADD CONSTRAINT crm_contacts_pkey PRIMARY KEY (id);


--
-- Name: layer_results layer_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_results
    ADD CONSTRAINT layer_results_pkey PRIMARY KEY (id);


--
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (id);


--
-- Name: module_costs module_costs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.module_costs
    ADD CONSTRAINT module_costs_pkey PRIMARY KEY (id);


--
-- Name: pixels pixels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pixels
    ADD CONSTRAINT pixels_pkey PRIMARY KEY (id);


--
-- Name: policy_versions policy_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_versions
    ADD CONSTRAINT policy_versions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: verification_runs verification_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_runs
    ADD CONSTRAINT verification_runs_pkey PRIMARY KEY (id);


--
-- Name: index_accounts_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_account_id ON public.accounts USING btree (account_id);


--
-- Name: index_accounts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_status ON public.accounts USING btree (status);


--
-- Name: index_activity_events_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_events_on_account_id ON public.activity_events USING btree (account_id);


--
-- Name: index_activity_events_on_account_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_events_on_account_id_and_occurred_at ON public.activity_events USING btree (account_id, occurred_at);


--
-- Name: index_activity_events_on_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_events_on_lead_id ON public.activity_events USING btree (lead_id);


--
-- Name: index_activity_events_on_lead_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_events_on_lead_id_and_occurred_at ON public.activity_events USING btree (lead_id, occurred_at);


--
-- Name: index_activity_events_on_verification_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_events_on_verification_run_id ON public.activity_events USING btree (verification_run_id);


--
-- Name: index_capture_sessions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capture_sessions_on_account_id ON public.capture_sessions USING btree (account_id);


--
-- Name: index_capture_sessions_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capture_sessions_on_account_id_and_created_at ON public.capture_sessions USING btree (account_id, created_at);


--
-- Name: index_capture_sessions_on_pixel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_capture_sessions_on_pixel_id ON public.capture_sessions USING btree (pixel_id);


--
-- Name: index_capture_sessions_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_capture_sessions_on_session_id ON public.capture_sessions USING btree (session_id);


--
-- Name: index_consensus_verdicts_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consensus_verdicts_on_account_id ON public.consensus_verdicts USING btree (account_id);


--
-- Name: index_consensus_verdicts_on_account_id_and_verdict; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consensus_verdicts_on_account_id_and_verdict ON public.consensus_verdicts USING btree (account_id, verdict);


--
-- Name: index_consensus_verdicts_on_policy_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consensus_verdicts_on_policy_version_id ON public.consensus_verdicts USING btree (policy_version_id);


--
-- Name: index_consensus_verdicts_on_verification_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consensus_verdicts_on_verification_run_id ON public.consensus_verdicts USING btree (verification_run_id);


--
-- Name: index_consent_certificates_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consent_certificates_on_account_id ON public.consent_certificates USING btree (account_id);


--
-- Name: index_consent_certificates_on_account_id_and_issued_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consent_certificates_on_account_id_and_issued_at ON public.consent_certificates USING btree (account_id, issued_at);


--
-- Name: index_consent_certificates_on_account_id_and_sequence_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consent_certificates_on_account_id_and_sequence_number ON public.consent_certificates USING btree (account_id, sequence_number);


--
-- Name: index_consent_certificates_on_certificate_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consent_certificates_on_certificate_uid ON public.consent_certificates USING btree (certificate_uid);


--
-- Name: index_consent_certificates_on_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consent_certificates_on_lead_id ON public.consent_certificates USING btree (lead_id);


--
-- Name: index_consent_certificates_on_verification_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consent_certificates_on_verification_run_id ON public.consent_certificates USING btree (verification_run_id);


--
-- Name: index_credit_ledger_entries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_ledger_entries_on_account_id ON public.credit_ledger_entries USING btree (account_id);


--
-- Name: index_credit_ledger_entries_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_ledger_entries_on_account_id_and_created_at ON public.credit_ledger_entries USING btree (account_id, created_at);


--
-- Name: index_credit_ledger_entries_on_verification_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_ledger_entries_on_verification_run_id ON public.credit_ledger_entries USING btree (verification_run_id);


--
-- Name: index_crm_contacts_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crm_contacts_on_account_id ON public.crm_contacts USING btree (account_id);


--
-- Name: index_crm_contacts_on_account_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crm_contacts_on_account_id_and_email ON public.crm_contacts USING btree (account_id, email);


--
-- Name: index_crm_contacts_on_account_id_and_external_crm_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crm_contacts_on_account_id_and_external_crm_id ON public.crm_contacts USING btree (account_id, external_crm_id);


--
-- Name: index_crm_contacts_on_account_id_and_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crm_contacts_on_account_id_and_phone ON public.crm_contacts USING btree (account_id, phone);


--
-- Name: index_layer_results_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_layer_results_on_account_id ON public.layer_results USING btree (account_id);


--
-- Name: index_layer_results_on_account_id_and_layer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_layer_results_on_account_id_and_layer ON public.layer_results USING btree (account_id, layer);


--
-- Name: index_layer_results_on_verification_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_layer_results_on_verification_run_id ON public.layer_results USING btree (verification_run_id);


--
-- Name: index_layer_results_on_verification_run_id_and_layer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_layer_results_on_verification_run_id_and_layer ON public.layer_results USING btree (verification_run_id, layer);


--
-- Name: index_leads_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leads_on_account_id ON public.leads USING btree (account_id);


--
-- Name: index_leads_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leads_on_account_id_and_created_at ON public.leads USING btree (account_id, created_at);


--
-- Name: index_leads_on_account_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leads_on_account_id_and_email ON public.leads USING btree (account_id, email);


--
-- Name: index_leads_on_account_id_and_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leads_on_account_id_and_phone ON public.leads USING btree (account_id, phone);


--
-- Name: index_leads_on_activity_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_leads_on_activity_token ON public.leads USING btree (activity_token);


--
-- Name: index_leads_on_capture_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leads_on_capture_session_id ON public.leads USING btree (capture_session_id);


--
-- Name: index_leads_on_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_leads_on_lead_id ON public.leads USING btree (lead_id);


--
-- Name: index_leads_on_pixel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leads_on_pixel_id ON public.leads USING btree (pixel_id);


--
-- Name: index_module_costs_on_layer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_module_costs_on_layer ON public.module_costs USING btree (layer);


--
-- Name: index_pixels_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pixels_on_account_id ON public.pixels USING btree (account_id);


--
-- Name: index_pixels_on_public_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pixels_on_public_id ON public.pixels USING btree (public_id);


--
-- Name: index_policy_versions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_policy_versions_on_account_id ON public.policy_versions USING btree (account_id);


--
-- Name: index_policy_versions_on_account_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_policy_versions_on_account_id_and_active ON public.policy_versions USING btree (account_id, active);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_account_id ON public.users USING btree (account_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_users_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role ON public.users USING btree (role);


--
-- Name: index_verification_runs_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verification_runs_on_account_id ON public.verification_runs USING btree (account_id);


--
-- Name: index_verification_runs_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verification_runs_on_account_id_and_created_at ON public.verification_runs USING btree (account_id, created_at);


--
-- Name: index_verification_runs_on_lead_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verification_runs_on_lead_id ON public.verification_runs USING btree (lead_id);


--
-- Name: index_verification_runs_on_policy_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_verification_runs_on_policy_version_id ON public.verification_runs USING btree (policy_version_id);


--
-- Name: consent_certificates consent_certificates_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER consent_certificates_immutable BEFORE DELETE OR UPDATE ON public.consent_certificates FOR EACH ROW EXECUTE FUNCTION public.block_consent_certificate_mutation();


--
-- Name: verification_runs fk_rails_1068edcd00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_runs
    ADD CONSTRAINT fk_rails_1068edcd00 FOREIGN KEY (lead_id) REFERENCES public.leads(id);


--
-- Name: pixels fk_rails_1ebf141d64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pixels
    ADD CONSTRAINT fk_rails_1ebf141d64 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: consensus_verdicts fk_rails_26aa7c1316; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consensus_verdicts
    ADD CONSTRAINT fk_rails_26aa7c1316 FOREIGN KEY (verification_run_id) REFERENCES public.verification_runs(id);


--
-- Name: layer_results fk_rails_29b658b37b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_results
    ADD CONSTRAINT fk_rails_29b658b37b FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: verification_runs fk_rails_372c99aa5c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_runs
    ADD CONSTRAINT fk_rails_372c99aa5c FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: credit_ledger_entries fk_rails_375344ef24; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_ledger_entries
    ADD CONSTRAINT fk_rails_375344ef24 FOREIGN KEY (verification_run_id) REFERENCES public.verification_runs(id) ON DELETE SET NULL;


--
-- Name: capture_sessions fk_rails_43e3bd2ece; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capture_sessions
    ADD CONSTRAINT fk_rails_43e3bd2ece FOREIGN KEY (pixel_id) REFERENCES public.pixels(id);


--
-- Name: consent_certificates fk_rails_4d2ecad811; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_certificates
    ADD CONSTRAINT fk_rails_4d2ecad811 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: crm_contacts fk_rails_4f85b6375f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crm_contacts
    ADD CONSTRAINT fk_rails_4f85b6375f FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: leads fk_rails_546ecca7f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT fk_rails_546ecca7f8 FOREIGN KEY (capture_session_id) REFERENCES public.capture_sessions(id);


--
-- Name: leads fk_rails_5a793df820; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT fk_rails_5a793df820 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: users fk_rails_61ac11da2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_61ac11da2b FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: activity_events fk_rails_66a102ee5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_events
    ADD CONSTRAINT fk_rails_66a102ee5b FOREIGN KEY (lead_id) REFERENCES public.leads(id) ON DELETE SET NULL;


--
-- Name: policy_versions fk_rails_6fe1d6b77e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_versions
    ADD CONSTRAINT fk_rails_6fe1d6b77e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: leads fk_rails_738108cb58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leads
    ADD CONSTRAINT fk_rails_738108cb58 FOREIGN KEY (pixel_id) REFERENCES public.pixels(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: activity_events fk_rails_8676161dee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_events
    ADD CONSTRAINT fk_rails_8676161dee FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: consensus_verdicts fk_rails_898c4858e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consensus_verdicts
    ADD CONSTRAINT fk_rails_898c4858e4 FOREIGN KEY (policy_version_id) REFERENCES public.policy_versions(id);


--
-- Name: capture_sessions fk_rails_8abee97c2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capture_sessions
    ADD CONSTRAINT fk_rails_8abee97c2e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: consent_certificates fk_rails_8ecd901ff5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_certificates
    ADD CONSTRAINT fk_rails_8ecd901ff5 FOREIGN KEY (verification_run_id) REFERENCES public.verification_runs(id);


--
-- Name: activity_events fk_rails_9cd793b78b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_events
    ADD CONSTRAINT fk_rails_9cd793b78b FOREIGN KEY (verification_run_id) REFERENCES public.verification_runs(id) ON DELETE SET NULL;


--
-- Name: consent_certificates fk_rails_a2af61e386; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_certificates
    ADD CONSTRAINT fk_rails_a2af61e386 FOREIGN KEY (lead_id) REFERENCES public.leads(id);


--
-- Name: layer_results fk_rails_b1b5c99682; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_results
    ADD CONSTRAINT fk_rails_b1b5c99682 FOREIGN KEY (verification_run_id) REFERENCES public.verification_runs(id);


--
-- Name: verification_runs fk_rails_c7b3062ef4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_runs
    ADD CONSTRAINT fk_rails_c7b3062ef4 FOREIGN KEY (policy_version_id) REFERENCES public.policy_versions(id);


--
-- Name: consensus_verdicts fk_rails_f644417733; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consensus_verdicts
    ADD CONSTRAINT fk_rails_f644417733 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: credit_ledger_entries fk_rails_f9ce52e692; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_ledger_entries
    ADD CONSTRAINT fk_rails_f9ce52e692 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260908120100'),
('20260908120000'),
('20260903215301'),
('20260903215300'),
('20260903215212'),
('20260903215211'),
('20260903215210'),
('20260903215209'),
('20260903215208'),
('20260903215207'),
('20260903215206'),
('20260903215205'),
('20260903215204'),
('20260903215203'),
('20260903215202'),
('20260903215201'),
('20260903215200'),
('20260903215159'),
('20260903215158');

