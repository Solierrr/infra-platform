
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id    uuid;
    v_ip         varchar(45);
    v_user_agent text;
    v_record_id  uuid;
BEGIN
    BEGIN
        v_user_id := NULLIF(current_setting('app.current_user_id', true), '')::uuid;
    EXCEPTION WHEN others THEN
        v_user_id := NULL;
    END;

    v_ip         := NULLIF(current_setting('app.client_ip', true), '');
    v_user_agent := NULLIF(current_setting('app.user_agent', true), '');

    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id;
    ELSE
        v_record_id := NEW.id;
    END IF;

    INSERT INTO audit_log (
        user_id, record_id, table_name, operation,
        ip_address, user_agent, previous_data, new_data
    ) VALUES (
        v_user_id,
        v_record_id,
        TG_TABLE_NAME,
        TG_OP::audit_operation,
        v_ip,
        v_user_agent,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_company ON company;
CREATE TRIGGER trg_audit_company AFTER INSERT OR UPDATE OR DELETE ON company
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_supplier ON supplier;
CREATE TRIGGER trg_audit_supplier AFTER INSERT OR UPDATE OR DELETE ON supplier
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_client ON client;
CREATE TRIGGER trg_audit_client AFTER INSERT OR UPDATE OR DELETE ON client
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_user_company ON user_company;
CREATE TRIGGER trg_audit_user_company AFTER INSERT OR UPDATE OR DELETE ON user_company
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_role_permission ON role_permission;
CREATE TRIGGER trg_audit_role_permission AFTER INSERT OR UPDATE OR DELETE ON role_permission
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_subscription ON subscription;
CREATE TRIGGER trg_audit_subscription AFTER INSERT OR UPDATE OR DELETE ON subscription
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_billing ON billing;
CREATE TRIGGER trg_audit_billing AFTER INSERT OR UPDATE OR DELETE ON billing
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_proposal ON proposal;
CREATE TRIGGER trg_audit_proposal AFTER INSERT OR UPDATE OR DELETE ON proposal
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_proposal_item ON proposal_item;
CREATE TRIGGER trg_audit_proposal_item AFTER INSERT OR UPDATE OR DELETE ON proposal_item
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_model ON model;
CREATE TRIGGER trg_audit_model AFTER INSERT OR UPDATE OR DELETE ON model
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_professional_registration ON professional_registration;
CREATE TRIGGER trg_audit_professional_registration AFTER INSERT OR UPDATE OR DELETE ON professional_registration
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_technical_project ON technical_project;
CREATE TRIGGER trg_audit_technical_project AFTER INSERT OR UPDATE OR DELETE ON technical_project
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_technical_service ON technical_service;
CREATE TRIGGER trg_audit_technical_service AFTER INSERT OR UPDATE OR DELETE ON technical_service
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_service_contract ON service_contract;
CREATE TRIGGER trg_audit_service_contract AFTER INSERT OR UPDATE OR DELETE ON service_contract
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_offer ON offer;
CREATE TRIGGER trg_audit_offer AFTER INSERT OR UPDATE OR DELETE ON offer
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS trg_audit_stock ON stock;
CREATE TRIGGER trg_audit_stock AFTER INSERT OR UPDATE OR DELETE ON stock
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();


CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposal_set_updated_at ON proposal;
CREATE TRIGGER trg_proposal_set_updated_at
    BEFORE UPDATE ON proposal
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


CREATE OR REPLACE FUNCTION fn_validate_cnpj(p_cnpj text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_digits    text;
    v_nums      int[];
    v_sum       int;
    v_weight    int;
    v_dv1       int;
    v_dv2       int;
    i           int;
BEGIN
    v_digits := regexp_replace(p_cnpj, '\D', '', 'g');

    IF length(v_digits) <> 14 THEN
        RETURN false;
    END IF;

    IF v_digits ~ '^(\d)\1{13}$' THEN
        RETURN false;
    END IF;

    v_nums := ARRAY(SELECT unnest(string_to_array(v_digits, NULL))::int);

    v_sum := 0;
    v_weight := 5;
    FOR i IN 1..12 LOOP
        v_sum := v_sum + v_nums[i] * v_weight;
        v_weight := v_weight - 1;
        IF v_weight < 2 THEN v_weight := 9; END IF;
    END LOOP;
    v_dv1 := 11 - (v_sum % 11);
    IF v_dv1 >= 10 THEN v_dv1 := 0; END IF;

    IF v_dv1 <> v_nums[13] THEN
        RETURN false;
    END IF;

    v_sum := 0;
    v_weight := 6;
    FOR i IN 1..13 LOOP
        v_sum := v_sum + v_nums[i] * v_weight;
        v_weight := v_weight - 1;
        IF v_weight < 2 THEN v_weight := 9; END IF;
    END LOOP;
    v_dv2 := 11 - (v_sum % 11);
    IF v_dv2 >= 10 THEN v_dv2 := 0; END IF;

    RETURN v_dv2 = v_nums[14];
END;
$$;

CREATE OR REPLACE FUNCTION fn_company_validate_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT fn_validate_cnpj(NEW.cnpj) THEN
        RAISE EXCEPTION 'CNPJ inválido: %', NEW.cnpj;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_cnpj ON company;
CREATE TRIGGER trg_validate_cnpj
    BEFORE INSERT OR UPDATE OF cnpj ON company
    FOR EACH ROW EXECUTE FUNCTION fn_company_validate_trigger();


CREATE OR REPLACE FUNCTION fn_address_validate_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.zip_code !~ '^\d{8}$' THEN
        RAISE EXCEPTION 'CEP inválido (esperado 8 dígitos numéricos): %', NEW.zip_code;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_cep ON address;
CREATE TRIGGER trg_validate_cep
    BEFORE INSERT OR UPDATE OF zip_code ON address
    FOR EACH ROW EXECUTE FUNCTION fn_address_validate_trigger();


CREATE OR REPLACE FUNCTION fn_registration_expiration_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.expiration_date <= current_date THEN
        RAISE EXCEPTION 'Registro profissional já vencido não pode ser cadastrado/atualizado (expiration_date: %)', NEW.expiration_date;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_registration_expiration ON professional_registration;
CREATE TRIGGER trg_registration_expiration
    BEFORE INSERT OR UPDATE OF expiration_date ON professional_registration
    FOR EACH ROW EXECUTE FUNCTION fn_registration_expiration_trigger();


CREATE OR REPLACE FUNCTION fn_offer_stock_consistency_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock_qty integer;
BEGIN
    SELECT quantity INTO v_stock_qty
    FROM stock
    WHERE supplier_id = NEW.supplier_id AND model_id = NEW.model_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Não é possível criar oferta: fornecedor % não possui estoque cadastrado para o modelo %', NEW.supplier_id, NEW.model_id;
    END IF;

    IF NEW.availability > v_stock_qty THEN
        RAISE EXCEPTION 'Disponibilidade da oferta (%) excede o estoque físico (%) do fornecedor % para o modelo %',
            NEW.availability, v_stock_qty, NEW.supplier_id, NEW.model_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_offer_stock_consistency ON offer;
CREATE TRIGGER trg_offer_stock_consistency
    BEFORE INSERT OR UPDATE OF availability, supplier_id, model_id ON offer
    FOR EACH ROW EXECUTE FUNCTION fn_offer_stock_consistency_trigger();


CREATE OR REPLACE FUNCTION fn_proposal_unit_quantity_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_item_quantity integer;
    v_allocated     integer;
BEGIN
    SELECT quantity INTO v_item_quantity
    FROM proposal_item
    WHERE id = NEW.proposal_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_item % não encontrado', NEW.proposal_item_id;
    END IF;

    SELECT COALESCE(SUM(quantity), 0) INTO v_allocated
    FROM proposal_unit
    WHERE proposal_item_id = NEW.proposal_item_id
      AND id <> NEW.id;

    IF (v_allocated + NEW.quantity) > v_item_quantity THEN
        RAISE EXCEPTION 'Quantidade alocada em proposal_unit (%) excede a quantidade do proposal_item (%)',
            (v_allocated + NEW.quantity), v_item_quantity;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposal_unit_quantity ON proposal_unit;
CREATE TRIGGER trg_proposal_unit_quantity
    BEFORE INSERT OR UPDATE OF quantity, proposal_item_id ON proposal_unit
    FOR EACH ROW EXECUTE FUNCTION fn_proposal_unit_quantity_trigger();


CREATE OR REPLACE FUNCTION fn_subscription_single_active_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.end_date IS NULL THEN
        IF EXISTS (
            SELECT 1 FROM subscription
            WHERE supplier_id = NEW.supplier_id
              AND end_date IS NULL
              AND id <> NEW.id
        ) THEN
            RAISE EXCEPTION 'Fornecedor % já possui uma assinatura em aberto', NEW.supplier_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_subscription_single_active ON subscription;
CREATE TRIGGER trg_subscription_single_active
    BEFORE INSERT OR UPDATE OF supplier_id, end_date ON subscription
    FOR EACH ROW EXECUTE FUNCTION fn_subscription_single_active_trigger();


CREATE OR REPLACE FUNCTION fn_prevent_company_delete_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM supplier s
        JOIN subscription sub ON sub.supplier_id = s.id
        WHERE s.company_id = OLD.id
          AND sub.status IN ('PAID', 'DELINQUENT')
          AND (sub.end_date IS NULL OR sub.end_date > now())
    ) THEN
        RAISE EXCEPTION 'Não é possível excluir a empresa %: existe assinatura ativa vinculada. Suspenda a assinatura e o fornecedor antes de excluir.', OLD.id;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_company_delete ON company;
CREATE TRIGGER trg_prevent_company_delete
    BEFORE DELETE ON company
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_company_delete_trigger();


CREATE OR REPLACE FUNCTION fn_proposal_recalculate_total_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_proposal_id uuid;
BEGIN
    v_proposal_id := COALESCE(NEW.proposal_id, OLD.proposal_id);

    UPDATE proposal
    SET total_amount = (
            SELECT COALESCE(SUM(
                pi.quantity * COALESCE(pi.negotiated_price, o.unit_price) * (1 - COALESCE(pi.discount, 0) / 100.0)
            ), 0)
            FROM proposal_item pi
            JOIN offer o ON o.id = pi.offer_id
            WHERE pi.proposal_id = v_proposal_id
        ),
        updated_at = now()
    WHERE id = v_proposal_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposal_recalculate_total ON proposal_item;
CREATE TRIGGER trg_proposal_recalculate_total
    AFTER INSERT OR UPDATE OR DELETE ON proposal_item
    FOR EACH ROW EXECUTE FUNCTION fn_proposal_recalculate_total_trigger();


CREATE OR REPLACE FUNCTION fn_billing_payment_date_consistency_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'PAID' AND NEW.payment_date IS NULL THEN
        NEW.payment_date := now();
    END IF;

    IF NEW.status <> 'PAID' AND NEW.payment_date IS NOT NULL THEN
        RAISE EXCEPTION 'payment_date só pode ser preenchido quando status = PAID (billing %)', NEW.id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_billing_payment_date_consistency ON billing;
CREATE TRIGGER trg_billing_payment_date_consistency
    BEFORE INSERT OR UPDATE OF status, payment_date ON billing
    FOR EACH ROW EXECUTE FUNCTION fn_billing_payment_date_consistency_trigger();


CREATE OR REPLACE FUNCTION fn_calculate_subscription_end_date(
    p_start_date timestamptz,
    p_billing_cycle billing_cycle
)
RETURNS timestamptz
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE p_billing_cycle
        WHEN 'WEEKLY'  THEN p_start_date + interval '7 days'
        WHEN 'MONTHLY' THEN p_start_date + interval '1 month'
        WHEN 'ANNUAL'  THEN p_start_date + interval '1 year'
    END;
$$;

CREATE OR REPLACE FUNCTION fn_supplier_available_stock(
    p_supplier_id uuid,
    p_model_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(quantity, 0)
    FROM stock
    WHERE supplier_id = p_supplier_id AND model_id = p_model_id;
$$;

CREATE OR REPLACE FUNCTION fn_get_active_subscription(p_supplier_id uuid)
RETURNS subscription
LANGUAGE sql
STABLE
AS $$
    SELECT *
    FROM subscription
    WHERE supplier_id = p_supplier_id
      AND end_date IS NULL
    LIMIT 1;
$$;


CREATE OR REPLACE PROCEDURE sp_create_company(
    p_state VARCHAR(2),
    p_city TEXT,
    p_neighborhood TEXT,
    p_zip_code VARCHAR(8),
    p_street TEXT,
    p_number VARCHAR(10),
    p_business_email VARCHAR(100),
    p_phone VARCHAR(20),
    p_website TEXT,
    p_cnpj VARCHAR(20),
    p_trade_name VARCHAR(120),
    p_legal_name VARCHAR(120),
    OUT p_company_id UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_address_id uuid;
    v_contact_id uuid;
BEGIN
    INSERT INTO address (state, city, neighborhood, zip_code, street, number)
    VALUES (p_state, p_city, p_neighborhood, p_zip_code, p_street, p_number)
    RETURNING id INTO v_address_id;

    INSERT INTO business_contact (business_email, phone, website)
    VALUES (p_business_email, p_phone, p_website)
    RETURNING id INTO v_contact_id;

    INSERT INTO company (address_id, business_contact_id, cnpj, trade_name, legal_name)
    VALUES (v_address_id, v_contact_id, p_cnpj, p_trade_name, p_legal_name)
    RETURNING id INTO p_company_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_assign_user_to_company(
    p_user_id UUID,
    p_company_id UUID,
    p_role_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_company (user_id, company_id, role_id)
    VALUES (p_user_id, p_company_id, p_role_id)
    ON CONFLICT ON CONSTRAINT uq_user_company_user_company
    DO UPDATE SET role_id = EXCLUDED.role_id;
END;
$$;


CREATE OR REPLACE PROCEDURE sp_generate_subscription_billing(
    p_subscription_id UUID,
    p_due_date DATE,
    p_payment_method payment_method DEFAULT 'BOLETO'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_amount numeric(12,2);
BEGIN
    SELECT sp.amount INTO v_amount
    FROM subscription s
    JOIN subscription_plan sp ON sp.id = s.plan_id
    WHERE s.id = p_subscription_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assinatura % não encontrada', p_subscription_id;
    END IF;

    INSERT INTO billing (subscription_id, amount, payment_method, status, due_date)
    VALUES (p_subscription_id, v_amount, p_payment_method, 'PENDING', p_due_date);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_accept_proposal(p_proposal_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    r          record;
    v_status   proposal_status;
BEGIN
    SELECT status INTO v_status
    FROM proposal
    WHERE id = p_proposal_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposta % não encontrada', p_proposal_id;
    END IF;

    IF v_status NOT IN ('OPEN', 'NEGOTIATING') THEN
        RAISE EXCEPTION 'Proposta % não pode ser aceita no status atual (%)', p_proposal_id, v_status;
    END IF;

    FOR r IN
        SELECT pi.id AS item_id, pi.quantity, o.supplier_id, o.model_id
        FROM proposal_item pi
        JOIN offer o ON o.id = pi.offer_id
        WHERE pi.proposal_id = p_proposal_id
    LOOP
        UPDATE stock
        SET quantity = quantity - r.quantity
        WHERE supplier_id = r.supplier_id
          AND model_id = r.model_id
          AND quantity >= r.quantity;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Estoque insuficiente para o modelo % do fornecedor % (proposal_item %)',
                r.model_id, r.supplier_id, r.item_id;
        END IF;
    END LOOP;

    UPDATE proposal
    SET status = 'ACCEPTED', updated_at = now()
    WHERE id = p_proposal_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_cancel_proposal(p_proposal_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    r        record;
    v_status proposal_status;
BEGIN
    SELECT status INTO v_status
    FROM proposal
    WHERE id = p_proposal_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposta % não encontrada', p_proposal_id;
    END IF;

    IF v_status = 'ACCEPTED' THEN
        FOR r IN
            SELECT pi.quantity, o.supplier_id, o.model_id
            FROM proposal_item pi
            JOIN offer o ON o.id = pi.offer_id
            WHERE pi.proposal_id = p_proposal_id
        LOOP
            UPDATE stock
            SET quantity = quantity + r.quantity
            WHERE supplier_id = r.supplier_id AND model_id = r.model_id;
        END LOOP;
    END IF;

    UPDATE proposal
    SET status = 'CANCELED', updated_at = now()
    WHERE id = p_proposal_id;
END;
$$;


CREATE OR REPLACE PROCEDURE sp_mark_delinquent_subscriptions()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE subscription s
    SET status = 'DELINQUENT'
    WHERE s.status = 'PAID'
      AND EXISTS (
          SELECT 1 FROM billing b
          WHERE b.subscription_id = s.id
            AND b.status = 'PENDING'
            AND b.due_date < CURRENT_DATE
      );
END;
$$;
