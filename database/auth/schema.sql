BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;


CREATE EXTENSION IF NOT EXISTS citext;


DO $$ BEGIN
    CREATE TYPE totp_algorithm AS ENUM ('SHA1', 'SHA256', 'SHA512');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


CREATE TABLE IF NOT EXISTS user_account (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email citext NOT NULL UNIQUE,
    password_hash text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    is_locked boolean NOT NULL DEFAULT false,
    last_login_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS address (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    state varchar(2) NOT NULL,
    city text NOT NULL,
    neighborhood text NOT NULL,
    zip_code varchar(8) NOT NULL,
    street text NOT NULL,
    number varchar(10) NOT NULL
);


CREATE TABLE IF NOT EXISTS geolocalization (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_address uuid NOT NULL UNIQUE,
    latitude numeric(10, 7) NOT NULL,
    longitude numeric(10, 7) NOT NULL,
    CONSTRAINT fk_geolocalization_address
        FOREIGN KEY (fk_address) REFERENCES address(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);

CREATE TABLE IF NOT EXISTS profile (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_user uuid NOT NULL UNIQUE,
    fk_address uuid,
    cpf varchar(11) NOT NULL UNIQUE,
    name varchar(120) NOT NULL,
    phone varchar(20),
    birth_date date NOT NULL,
    avatar text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_profile_user
        FOREIGN KEY (fk_user) REFERENCES user_account(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_profile_address
        FOREIGN KEY (fk_address) REFERENCES address(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS token (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_user uuid NOT NULL,
    token varchar(255) NOT NULL UNIQUE,
    type varchar(30) NOT NULL,
    expires_at timestamptz NOT NULL,
    used boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_token_user
        FOREIGN KEY (fk_user) REFERENCES user_account(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS refresh_token (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_user uuid NOT NULL,
    token text NOT NULL UNIQUE,
    revoked boolean NOT NULL DEFAULT false,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_refresh_token_user
        FOREIGN KEY (fk_user) REFERENCES user_account(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS session (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_user uuid NOT NULL,
    fk_refresh_token uuid NOT NULL,
    ip varchar(45),
    user_agent text,
    device text,
    revoked boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_access_at timestamptz,
    CONSTRAINT fk_session_user
        FOREIGN KEY (fk_user) REFERENCES user_account(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT fk_session_refresh_token
        FOREIGN KEY (fk_refresh_token) REFERENCES refresh_token(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS oauth_account (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_user uuid NOT NULL,
    provider varchar(20) NOT NULL,
    provider_user_id varchar(200) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_oauth_account_provider_external_id UNIQUE (provider, provider_user_id),
    CONSTRAINT fk_oauth_account_user
        FOREIGN KEY (fk_user) REFERENCES user_account(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE TABLE IF NOT EXISTS two_factor (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fk_user uuid NOT NULL UNIQUE,
    secret text NOT NULL,
    enabled boolean NOT NULL DEFAULT false,
    backup_codes text,
    algorithm totp_algorithm NOT NULL DEFAULT 'SHA1',
    digits smallint NOT NULL DEFAULT 6 CHECK (digits IN (6, 8)),
    period smallint NOT NULL DEFAULT 30 CHECK (period > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_two_factor_user
        FOREIGN KEY (fk_user) REFERENCES user_account(id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);


CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_user_account_updated_at
BEFORE UPDATE
ON user_account
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_profile_updated_at
BEFORE UPDATE
ON profile
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();


CREATE OR REPLACE PROCEDURE clean_expired_data()
LANGUAGE plpgsql
AS $$
BEGIN

    DELETE FROM session
    WHERE fk_refresh_token IN (
        SELECT id
        FROM refresh_token
        WHERE expires_at < now()
           OR revoked = true
    );

    DELETE FROM refresh_token
    WHERE expires_at < now()
       OR revoked = true;

    DELETE FROM token
    WHERE expires_at < now()
       OR used = true;

END;
$$;


COMMIT;