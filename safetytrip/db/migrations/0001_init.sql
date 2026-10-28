-- SafetyTrip MVP — initial schema (PRD §6)
-- PostgreSQL + PostGIS. UUID PK, UTC timestamps, 공통 created_at/updated_at.
-- 좌표는 EPSG:4326 geography(Point). JSON 직렬화는 lat,lon 순서 고정(§6 주의).

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- gen_random_uuid()

-- 공통 updated_at 트리거
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE cities (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug         text NOT NULL UNIQUE,
  name_ko      text NOT NULL,
  country_code text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE areas (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id       uuid NOT NULL REFERENCES cities(id) ON DELETE CASCADE,
  slug          text NOT NULL,
  name_ko       text NOT NULL,
  boundary_geom geography(Polygon, 4326), -- 선택: 지역 경계 (D-05)
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (city_id, slug)
);

CREATE TABLE sources (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider       text NOT NULL,
  license_url    text,
  attribution    text,
  retrieved_at   timestamptz,
  permitted_uses text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TYPE property_status AS ENUM ('public', 'closed', 'unverified_location');

CREATE TABLE properties (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text NOT NULL UNIQUE,
  city_id     uuid NOT NULL REFERENCES cities(id),
  area_id     uuid REFERENCES areas(id),
  name        text NOT NULL,
  name_local  text,
  address     text,
  location    geography(Point, 4326),               -- NULL 허용: 좌표 미검증
  source_id   uuid REFERENCES sources(id),
  verified_at timestamptz,
  status      property_status NOT NULL DEFAULT 'public',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_properties_location ON properties USING GIST (location);
CREATE INDEX idx_properties_name ON properties USING GIN (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(name_local, '')));
CREATE INDEX idx_properties_city_area ON properties (city_id, area_id);

-- 검색어 변형(별칭) 테이블 (§6 권장, D-08)
CREATE TABLE property_aliases (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  alias       text NOT NULL,
  language    text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_property_aliases_alias ON property_aliases USING GIN (to_tsvector('simple', alias));

CREATE TABLE stations (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id          uuid NOT NULL REFERENCES cities(id),
  station_group_id text NOT NULL,            -- 동일역 그룹 (여러 노선 중복 합산, D-04)
  name             text NOT NULL,
  name_local       text,
  location         geography(Point, 4326),
  lines            jsonb NOT NULL DEFAULT '[]'::jsonb,
  source_id        uuid REFERENCES sources(id),
  verified_at      timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_stations_location ON stations USING GIST (location);
CREATE INDEX idx_stations_group ON stations (station_group_id);

-- 거리 캐시. 좌표/알고리즘 버전 변경 시 무효화·재산출 (FR-03, FR-08)
CREATE TABLE property_station_distances (
  property_id       uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  station_id        uuid NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  distance_m        integer NOT NULL CHECK (distance_m >= 0),
  algorithm_version text NOT NULL,
  computed_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (property_id, station_id)
);

CREATE TYPE issue_status AS ENUM ('open', 'reviewing', 'resolved', 'rejected');
CREATE TYPE issue_type AS ENUM ('location', 'name', 'closed', 'station', 'other');

CREATE TABLE data_issues (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  issue_type  issue_type NOT NULL,
  details     text NOT NULL,                 -- 공개 입력: 서버에서 sanitize
  contact     text,                          -- 선택, 기본 미수집 (FR-07)
  status      issue_status NOT NULL DEFAULT 'open',
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE audit_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    uuid,
  entity_type text NOT NULL,
  entity_id   uuid,
  action      text NOT NULL,
  diff        jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- updated_at 트리거 부착
CREATE TRIGGER t_cities_updated BEFORE UPDATE ON cities FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER t_areas_updated BEFORE UPDATE ON areas FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER t_sources_updated BEFORE UPDATE ON sources FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER t_properties_updated BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER t_stations_updated BEFORE UPDATE ON stations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
