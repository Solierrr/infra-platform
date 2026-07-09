BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;


DO $$ BEGIN
    CREATE TYPE model_status AS ENUM ('approved', 'rejected', 'under_analysis');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE supplier_status AS ENUM ('active', 'suspended', 'deactivated');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE proposal_status AS ENUM ('open', 'in_negotiation', 'accepted', 'rejected', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_status AS ENUM ('paid', 'in_debt', 'suspended');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE service_status AS ENUM ('open', 'in_progress', 'completed', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE plan_cycle AS ENUM ('monthly', 'quarterly', 'yearly');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE location_type AS ENUM ('building', 'house', 'complex');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE technical_affiliation_type AS ENUM ('independent', 'affiliated', 'partner');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM ('pix', 'boleto', 'credit_card', 'transfer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE billing_status AS ENUM ('pending', 'paid', 'canceled', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    avatar text
);

CREATE TABLE IF NOT EXISTS contact (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    work_email varchar(100),
    personal_email varchar(100),
    work_phone varchar(12),
    personal_phone varchar(12)
);

CREATE TABLE IF NOT EXISTS business_contact (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_email varchar(100) NOT NULL,
    phone varchar(12),
    website text
);

CREATE TABLE IF NOT EXISTS address (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    state varchar(2) NOT NULL,
    city text NOT NULL,
    neighborhood text,
    zip_code varchar(8) NOT NULL,
    street text NOT NULL,
    number varchar(10)
);


CREATE TABLE IF NOT EXISTS geolocalization (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_address uuid NOT NULL,
    latitude numeric(10, 7) NOT NULL,
    longitude numeric(10, 7) NOT NULL,
    CONSTRAINT fk_geolocalization_address
        FOREIGN KEY (fk_address) REFERENCES address(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS position (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(12) NOT NULL,
    accesses text NOT NULL
);

CREATE TABLE IF NOT EXISTS company (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_address uuid NOT NULL,
    fk_business_contact uuid NOT NULL,
    cnpj varchar(14) NOT NULL,
    trade_name varchar(120) NOT NULL,
    CONSTRAINT fk_company_address
        FOREIGN KEY (fk_address) REFERENCES address(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_company_business_contact
        FOREIGN KEY (fk_business_contact) REFERENCES business_contact(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS user_company (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_company uuid NOT NULL,
    fk_users uuid NOT NULL,
    fk_position uuid NOT NULL,
    CONSTRAINT fk_user_company_company
        FOREIGN KEY (fk_company) REFERENCES company(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_user_company_user
        FOREIGN KEY (fk_users) REFERENCES users(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_user_company_position
        FOREIGN KEY (fk_position) REFERENCES position(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS company_positions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_company uuid NOT NULL,
    fk_position uuid NOT NULL,
    CONSTRAINT fk_company_positions_company
        FOREIGN KEY (fk_company) REFERENCES company(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_company_positions_position
        FOREIGN KEY (fk_position) REFERENCES position(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS person (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_users uuid,
    fk_contact uuid,
    name varchar(60) NOT NULL,
    cpf varchar(11) NOT NULL,
    birth_date date NOT NULL,
    CONSTRAINT fk_person_user
        FOREIGN KEY (fk_users) REFERENCES users(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_person_contact
        FOREIGN KEY (fk_contact) REFERENCES contact(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS technician (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_person uuid NOT NULL,
    crea text NOT NULL,
    CONSTRAINT fk_technician_person
        FOREIGN KEY (fk_person) REFERENCES person(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS specialization (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    type text NOT NULL
);

CREATE TABLE IF NOT EXISTS technician_specialization (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_technician uuid NOT NULL,
    fk_specialization uuid NOT NULL,
    CONSTRAINT fk_technician_specialization_technician
        FOREIGN KEY (fk_technician) REFERENCES technician(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_technician_specialization_specialization
        FOREIGN KEY (fk_specialization) REFERENCES specialization(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS technical_company (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_company uuid NOT NULL,
    CONSTRAINT fk_technical_company_company
        FOREIGN KEY (fk_company) REFERENCES company(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS supplier (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_company uuid NOT NULL,
    status supplier_status NOT NULL DEFAULT 'active',
    CONSTRAINT fk_supplier_company
        FOREIGN KEY (fk_company) REFERENCES company(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS requester (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_company uuid NOT NULL,
    CONSTRAINT fk_requester_company
        FOREIGN KEY (fk_company) REFERENCES company(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS company_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    value money NOT NULL,
    cycle plan_cycle NOT NULL
);

CREATE TABLE IF NOT EXISTS subscription (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_supplier uuid NOT NULL,
    fk_plan uuid NOT NULL,
    status subscription_status NOT NULL DEFAULT 'paid',
    auto_renewal boolean NOT NULL DEFAULT true,
    start_date timestamptz NOT NULL,
    end_date timestamptz,
    CONSTRAINT fk_subscription_supplier
        FOREIGN KEY (fk_supplier) REFERENCES supplier(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_subscription_plan
        FOREIGN KEY (fk_plan) REFERENCES company_plans(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS charge (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_subscription uuid NOT NULL,
    amount money NOT NULL,
    payment_method payment_method NOT NULL,
    status billing_status NOT NULL DEFAULT 'pending',
    payment_date timestamptz,
    CONSTRAINT fk_charge_subscription
        FOREIGN KEY (fk_subscription) REFERENCES subscription(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS model (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand text NOT NULL,
    model text NOT NULL,
    power_wp numeric NOT NULL,
    efficiency numeric NOT NULL,
    dimension numeric NOT NULL,
    weight numeric NOT NULL,
    status model_status NOT NULL DEFAULT 'under_analysis'
);

CREATE TABLE IF NOT EXISTS inventory (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_supplier uuid NOT NULL,
    fk_model uuid NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT fk_inventory_supplier
        FOREIGN KEY (fk_supplier) REFERENCES supplier(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_inventory_model
        FOREIGN KEY (fk_model) REFERENCES model(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS offer (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_supplier uuid NOT NULL,
    fk_model uuid NOT NULL,
    unit_price money NOT NULL,
    availability integer NOT NULL,
    expiration_date timestamptz,
    CONSTRAINT fk_offer_supplier
        FOREIGN KEY (fk_supplier) REFERENCES supplier(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_offer_model
        FOREIGN KEY (fk_model) REFERENCES model(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS local_unit (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_requester uuid NOT NULL,
    fk_address uuid NOT NULL,
    complement text,
    location_type location_type NOT NULL,
    CONSTRAINT fk_local_unit_requester
        FOREIGN KEY (fk_requester) REFERENCES requester(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_local_unit_address
        FOREIGN KEY (fk_address) REFERENCES address(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS unit_specifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_local_unit uuid NOT NULL,
    specifications text,
    location_photos text,
    date timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_unit_specifications_local_unit
        FOREIGN KEY (fk_local_unit) REFERENCES local_unit(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS energy_bill (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_local_unit uuid NOT NULL,
    consumption numeric NOT NULL,
    price money NOT NULL,
    CONSTRAINT fk_energy_bill_local_unit
        FOREIGN KEY (fk_local_unit) REFERENCES local_unit(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS proposal (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_requester uuid NOT NULL,
    status proposal_status NOT NULL DEFAULT 'open',
    notes text,
    total_amount money,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT fk_proposal_requester
        FOREIGN KEY (fk_requester) REFERENCES requester(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS proposal_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_proposal uuid NOT NULL,
    fk_offer uuid NOT NULL,
    quantity integer NOT NULL,
    negotiated_price money,
    discount numeric,
    CONSTRAINT fk_proposal_item_proposal
        FOREIGN KEY (fk_proposal) REFERENCES proposal(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_proposal_item_offer
        FOREIGN KEY (fk_offer) REFERENCES offer(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS proposal_unit (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_proposal_item uuid NOT NULL,
    fk_local_unit uuid NOT NULL,
    quantity integer NOT NULL,
    note text,
    CONSTRAINT fk_proposal_unit_item
        FOREIGN KEY (fk_proposal_item) REFERENCES proposal_item(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_proposal_unit_local
        FOREIGN KEY (fk_local_unit) REFERENCES local_unit(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS technical_service (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_requester uuid NOT NULL,
    purpose text NOT NULL,
    status service_status NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_technical_service_requester
        FOREIGN KEY (fk_requester) REFERENCES requester(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS technician_affiliation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_company uuid NOT NULL,
    fk_technician uuid NOT NULL,
    affiliation_type technical_affiliation_type NOT NULL,
    CONSTRAINT fk_technician_affiliation_company
        FOREIGN KEY (fk_company) REFERENCES company(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_technician_affiliation_technician
        FOREIGN KEY (fk_technician) REFERENCES technician(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS service_executor (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_service uuid NOT NULL,
    fk_technician_affiliation uuid NOT NULL,
    role text NOT NULL,
    CONSTRAINT fk_service_executor_service
        FOREIGN KEY (fk_service) REFERENCES technical_service(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_service_executor_technician_affiliation
        FOREIGN KEY (fk_technician_affiliation) REFERENCES technician_affiliation(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS service_contract (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_service uuid NOT NULL,
    warranty text,
    delivery_deadline date,
    insurance boolean NOT NULL DEFAULT false,
    utility_approval boolean NOT NULL DEFAULT false,
    CONSTRAINT fk_service_contract_service
        FOREIGN KEY (fk_service) REFERENCES technical_service(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE permission (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_name VARCHAR(100) NOT NULL UNIQUE
);


CREATE TABLE position_permission (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_position UUID NOT NULL,
    id_permission UUID NOT NULL,

CONSTRAINT fk_position FOREIGN KEY (id_position) REFERENCES position(id) ON DELETE CASCADE,
CONSTRAINT fk_permission FOREIGN KEY (id_permission) REFERENCES permission(id) ON DELETE CASCADE

);

COMMIT;