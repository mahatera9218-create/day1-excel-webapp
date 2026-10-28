import { describe, it, expect } from "vitest";
import {
  bearingDegrees,
  classifyMeters,
  computeNearbyStations,
  displayMeters,
  geodesicDistanceMeters,
  isValidLatLon,
  MAX_SEARCH_RADIUS_M,
  type StationLike,
} from "../src/lib/distance";

describe("isValidLatLon", () => {
  it("accepts in-range coords", () => {
    expect(isValidLatLon({ lat: 35.69, lon: 139.7 })).toBe(true);
    expect(isValidLatLon({ lat: -90, lon: 180 })).toBe(true);
  });
  it("rejects out-of-range / missing / NaN", () => {
    expect(isValidLatLon({ lat: 91, lon: 0 })).toBe(false);
    expect(isValidLatLon({ lat: 0, lon: 181 })).toBe(false);
    expect(isValidLatLon({ lat: NaN, lon: 0 })).toBe(false);
    expect(isValidLatLon(null)).toBe(false);
    expect(isValidLatLon({ lat: 35 })).toBe(false);
  });
});

describe("geodesicDistanceMeters", () => {
  it("returns 0 for identical points (same coordinate, QA: 동일 좌표 일관)", () => {
    const p = { lat: 35.6896, lon: 139.7006 };
    expect(geodesicDistanceMeters(p, p)).toBe(0);
  });
  it("returns null on invalid input (never a fake distance)", () => {
    expect(geodesicDistanceMeters({ lat: 999, lon: 0 }, { lat: 0, lon: 0 })).toBeNull();
  });
  it("is within ~0.3% of a known reference (Shinjuku <-> Shibuya ~3.4km)", () => {
    const d = geodesicDistanceMeters(
      { lat: 35.6896, lon: 139.7006 },
      { lat: 35.658, lon: 139.7016 },
    )!;
    // reference great-circle ~3514m; allow tolerance
    expect(d).toBeGreaterThan(3400);
    expect(d).toBeLessThan(3650);
  });
});

describe("classifyMeters boundary labels (QA #6: 300/301, 600/601, 1000/1001)", () => {
  const cases: Array<[number, string | null]> = [
    [0, "매우 가까움"],
    [300, "매우 가까움"],
    [301, "가까움"],
    [600, "가까움"],
    [601, "다소 이동 필요"],
    [1000, "다소 이동 필요"],
    [1001, "접근성 추가 확인"],
    [5000, "접근성 추가 확인"],
  ];
  it.each(cases)("%d m -> %s", (m, label) => {
    expect(classifyMeters(m)).toBe(label);
  });
  it("returns null for unknown / negative", () => {
    expect(classifyMeters(null)).toBeNull();
    expect(classifyMeters(-1)).toBeNull();
  });
});

describe("displayMeters", () => {
  it("rounds consistently to integer meters", () => {
    expect(displayMeters(450.4)).toBe(450);
    expect(displayMeters(450.5)).toBe(451);
  });
  it("passes null through (미확인, never 0)", () => {
    expect(displayMeters(null)).toBeNull();
  });
});

describe("bearingDegrees", () => {
  const origin = { lat: 35.69, lon: 139.7 };
  it("points ~north / east / south / west correctly", () => {
    expect(bearingDegrees(origin, { lat: 35.70, lon: 139.7 })!).toBeCloseTo(0, 0); // north
    expect(bearingDegrees(origin, { lat: 35.69, lon: 139.71 })!).toBeGreaterThan(80);
    expect(bearingDegrees(origin, { lat: 35.69, lon: 139.71 })!).toBeLessThan(100); // ~east
    expect(bearingDegrees(origin, { lat: 35.68, lon: 139.7 })!).toBeCloseTo(180, 0); // south
  });
  it("returns a value in [0,360) and null on invalid", () => {
    const b = bearingDegrees(origin, { lat: 35.69, lon: 139.69 })!;
    expect(b).toBeGreaterThanOrEqual(0);
    expect(b).toBeLessThan(360);
    expect(bearingDegrees(origin, { lat: 999, lon: 0 })).toBeNull();
  });
});

describe("computeNearbyStations", () => {
  const stations: StationLike[] = [
    { id: "st-shinjuku", name: "新宿駅", location: { lat: 35.6896, lon: 139.7006 } },
    { id: "st-shibuya", name: "渋谷駅", location: { lat: 35.658, lon: 139.7016 } },
    { id: "st-nocoord", name: "No Coord", location: null },
  ];

  it("returns [] when property has no valid coords (상세에서 미확인)", () => {
    expect(computeNearbyStations(null, stations)).toEqual([]);
    expect(computeNearbyStations({ lat: 999, lon: 0 }, stations)).toEqual([]);
  });

  it("orders by distance ascending and classifies", () => {
    const near = { lat: 35.69, lon: 139.701 };
    const out = computeNearbyStations(near, stations, 3);
    expect(out[0].id).toBe("st-shinjuku");
    expect(out[0].classification).toBe("매우 가까움");
    expect(out.find((s) => s.id === "st-nocoord")).toBeUndefined();
    // all distances are integers, never 0-as-missing
    out.forEach((s) => expect(Number.isInteger(s.straight_distance_m)).toBe(true));
  });

  it("excludes stations beyond MAX_SEARCH_RADIUS_M (no false nearest)", () => {
    const faraway: StationLike[] = [
      { id: "st-osaka", name: "大阪駅", location: { lat: 34.7025, lon: 135.4959 } },
    ];
    const tokyo = { lat: 35.69, lon: 139.701 };
    expect(geodesicDistanceMeters(tokyo, faraway[0].location!)!).toBeGreaterThan(
      MAX_SEARCH_RADIUS_M,
    );
    expect(computeNearbyStations(tokyo, faraway)).toEqual([]);
  });

  it("breaks ties by id ASC (stable ordering)", () => {
    const sameSpot: StationLike[] = [
      { id: "st-b", name: "B", location: { lat: 35.69, lon: 139.701 } },
      { id: "st-a", name: "A", location: { lat: 35.69, lon: 139.701 } },
    ];
    const out = computeNearbyStations({ lat: 35.69, lon: 139.701 }, sameSpot, 2);
    expect(out.map((s) => s.id)).toEqual(["st-a", "st-b"]);
  });
});
