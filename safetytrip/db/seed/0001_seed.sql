-- SafetyTrip dev seed — mirrors src/data/seed-data.ts (SSOT). 둘이 어긋나면 안 됨.
-- 전부 샘플/테스트 데이터. 실재 숙소 아님. 역 좌표는 근사치(출시 전 D-04 검증 교체).
-- lat,lon 순서 고정. ST_MakePoint 는 (lon, lat) 순서임에 주의.

INSERT INTO sources (provider, license_url, attribution, retrieved_at, permitted_uses)
VALUES ('manual-sample', '', 'Sample/test data for development. Not real listings.', '2026-10-01T00:00:00Z', 'internal-development-only')
ON CONFLICT DO NOTHING;

INSERT INTO cities (slug, name_ko, country_code) VALUES ('tokyo', '도쿄', 'JP')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO areas (city_id, slug, name_ko)
SELECT c.id, v.slug, v.name_ko
FROM cities c, (VALUES
  ('shinjuku', '신주쿠'), ('shibuya', '시부야'), ('ueno', '우에노'), ('asakusa', '아사쿠사')
) AS v(slug, name_ko)
WHERE c.slug = 'tokyo'
ON CONFLICT (city_id, slug) DO NOTHING;

-- 역 (name, name_local, lat, lon, lines, group)
INSERT INTO stations (city_id, station_group_id, name, name_local, location, lines, source_id, verified_at)
SELECT c.id, v.grp, v.name, v.name_local,
       ST_SetSRID(ST_MakePoint(v.lon, v.lat), 4326)::geography,
       v.lines::jsonb, s.id, '2026-10-01T00:00:00Z'
FROM cities c
CROSS JOIN LATERAL (SELECT id FROM sources WHERE provider = 'manual-sample' LIMIT 1) s,
(VALUES
  ('grp-shinjuku','Shinjuku','新宿駅',35.6896,139.7006,'["JR","Odakyu","Keio","Tokyo Metro"]'),
  ('grp-shinjuku-sanchome','Shinjuku-sanchome','新宿三丁目駅',35.6916,139.7050,'["Tokyo Metro","Toei"]'),
  ('grp-shibuya','Shibuya','渋谷駅',35.6580,139.7016,'["JR","Tokyu","Tokyo Metro"]'),
  ('grp-harajuku','Harajuku','原宿駅',35.6702,139.7026,'["JR"]'),
  ('grp-ueno','Ueno','上野駅',35.7141,139.7774,'["JR","Tokyo Metro"]'),
  ('grp-okachimachi','Okachimachi','御徒町駅',35.7076,139.7745,'["JR"]'),
  ('grp-asakusa','Asakusa','浅草駅',35.7119,139.7983,'["Tokyo Metro","Toei","Tobu"]'),
  ('grp-tawaramachi','Tawaramachi','田原町駅',35.7101,139.7920,'["Tokyo Metro"]')
) AS v(grp, name, name_local, lat, lon, lines)
WHERE c.slug = 'tokyo';

-- 숙소 (slug 고정). 좌표 NULL 케이스 포함.
INSERT INTO properties (slug, city_id, area_id, name, name_local, address, location, source_id, verified_at, status)
SELECT v.slug, c.id, a.id, v.name, v.name_local, v.address,
       CASE WHEN v.lat IS NULL THEN NULL
            ELSE ST_SetSRID(ST_MakePoint(v.lon, v.lat), 4326)::geography END,
       s.id, v.verified_at::timestamptz, v.status::property_status
FROM cities c
JOIN areas a ON a.city_id = c.id
CROSS JOIN LATERAL (SELECT id FROM sources WHERE provider = 'manual-sample' LIMIT 1) s,
(VALUES
  ('sample-hotel-shinjuku','shinjuku','Sample Hotel Shinjuku','サンプルホテル新宿','Tokyo, Shinjuku (sample address)',35.6905::float,139.7010::float,'2026-10-01T00:00:00Z','public'),
  ('sample-hotel-shinjuku-east','shinjuku','Sample Hotel Shinjuku','サンプルホテル新宿イースト','Tokyo, Shinjuku-sanchome (sample address, different building)',35.6920,139.7055,'2026-10-01T00:00:00Z','public'),
  ('sample-inn-shibuya','shibuya','Sample Inn Shibuya','サンプルイン渋谷','Tokyo, Shibuya (sample address)',35.6590,139.7030,'2026-10-01T00:00:00Z','public'),
  ('sample-ryokan-ueno','ueno','Sample Ryokan Ueno','サンプル旅館上野','Tokyo, Ueno (sample address)',35.7128,139.7760,'2026-10-01T00:00:00Z','public'),
  ('sample-stay-asakusa','asakusa','Sample Stay Asakusa','サンプルステイ浅草','Tokyo, Asakusa (sample address)',35.7112,139.7975,'2026-10-01T00:00:00Z','public'),
  ('sample-stay-no-coords','ueno','Sample Stay (No Coordinates)','サンプルステイ（座標未検証）','Tokyo, Ueno (location not yet verified)',NULL,NULL,NULL,'unverified_location')
) AS v(slug, area_slug, name, name_local, address, lat, lon, verified_at, status)
WHERE c.slug = 'tokyo' AND a.slug = v.area_slug
ON CONFLICT (slug) DO NOTHING;
