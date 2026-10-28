-- 근접역 상위 N개 (FR-03 프로덕션 쿼리).
-- 후보 영역을 ST_DWithin 으로 먼저 제한(인덱스 활용 + 5km 밖 배제),
-- 동일역 그룹은 그룹당 가장 가까운 1건으로 중복 제거, 거리 ASC·id ASC 안정 정렬.
-- $1 = property_id, $2 = limit, 5000 = MAX_SEARCH_RADIUS_M.
WITH prop AS (
  SELECT id, location FROM properties WHERE id = $1 AND location IS NOT NULL
),
candidates AS (
  SELECT s.id, s.station_group_id, s.name, s.name_local, s.lines,
         ST_Distance(p.location, s.location) AS dist_m,
         ROW_NUMBER() OVER (
           PARTITION BY s.station_group_id
           ORDER BY ST_Distance(p.location, s.location) ASC, s.id ASC
         ) AS rn_in_group
  FROM prop p
  JOIN stations s
    ON s.city_id = (SELECT city_id FROM properties WHERE id = $1)
   AND s.location IS NOT NULL
   AND ST_DWithin(p.location, s.location, 5000)  -- MAX_SEARCH_RADIUS_M
)
SELECT id, name, name_local, lines,
       ROUND(dist_m)::int AS straight_distance_m
FROM candidates
WHERE rn_in_group = 1
ORDER BY dist_m ASC, id ASC
LIMIT $2;
