import fs from "fs";
import os from "os";
import path from "path";
import request from "supertest";
import { loadManifest, seedRows } from "../muezzins.manifest";

const mockFindMany = jest.fn();
jest.mock("../../../config/prisma", () => ({ prisma: { muezzin: { findMany: mockFindMany } } }));
jest.mock("../../../config/env", () => ({
  env: { mediaBaseUrl: "http://10.0.2.2:4000", corsOrigin: "*", jwtSecret: "test", jwtExpiresIn: "1h" },
}));

import { createApp } from "../../../app";

/** The seeded table, queried the way Prisma would. */
function seededTable() {
  const rows = seedRows(loadManifest()).map((r, i) => ({ id: r.id, ...r.data, createdAt: new Date(i) }));
  return ({ where, orderBy }: { where: { isActive: boolean }; orderBy: { sortOrder?: "asc" }[] }) => {
    expect(orderBy[0]).toEqual({ sortOrder: "asc" });
    return rows
      .filter((r) => r.isActive === where.isActive)
      .sort((a, b) => a.sortOrder - b.sortOrder || a.createdAt.getTime() - b.createdAt.getTime());
  };
}

describe("GET /api/muezzins", () => {
  it("returns the seeded muezzins in sortOrder with absolute urls", async () => {
    mockFindMany.mockImplementation(seededTable());
    const res = await request(createApp()).get("/api/muezzins").expect(200);

    const expected = loadManifest()
      .muezzins.filter((m) => m.status === "ok")
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((m) => m.id);
    expect(res.body.muezzins.map((m: { id: string }) => m.id)).toEqual(expected);
    // Algeria first: most users are there.
    expect(res.body.muezzins[0].id).toBe("00000000-0000-4000-8000-000000000003");

    for (const m of res.body.muezzins) {
      for (const key of ["regularUrl", "fajrUrl", "regularShortUrl", "fajrShortUrl"]) {
        expect(m[key]).toMatch(/^http:\/\/10\.0\.2\.2:4000\/adhan\/[a-z]+\/v\d+\/[a-z_]+\.(mp3|caf)$/);
      }
      expect(m.regularUrl).toContain(`/v${m.version}/`);
    }
  });
});

describe("seedRows", () => {
  it("keeps the old ids and deactivates a row that failed the import", () => {
    const manifest = loadManifest();
    const ids = Object.fromEntries(manifest.muezzins.map((m) => [m.slug, m.id]));
    expect(ids.makkah).toBe("00000000-0000-4000-8000-000000000001");
    expect(ids.madinah).toBe("00000000-0000-4000-8000-000000000002");
    expect(ids.algeria).toBe("00000000-0000-4000-8000-000000000003");

    manifest.muezzins[0].status = "failed";
    const rows = seedRows(manifest);
    expect(rows[0].data.isActive).toBe(false);
    expect(rows[0].data.regularUrl.startsWith("/adhan/")).toBe(true);
  });
});

describe("/adhan static files", () => {
  let dir: string;
  const mp3 = Buffer.alloc(1000, 7);

  beforeAll(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "adhan-"));
    fs.mkdirSync(path.join(dir, "test/v1"), { recursive: true });
    fs.writeFileSync(path.join(dir, "test/v1/regular.mp3"), mp3);
    fs.writeFileSync(path.join(dir, "test/v1/regular_short.caf"), Buffer.alloc(10));
  });
  afterAll(() => fs.rmSync(dir, { recursive: true, force: true }));

  it("serves an mp3 as audio/mpeg, cached for good", async () => {
    const res = await request(createApp({ adhanDir: dir })).get("/adhan/test/v1/regular.mp3").expect(200);
    expect(res.headers["content-type"]).toBe("audio/mpeg");
    expect(res.headers["cache-control"]).toBe("public, max-age=2592000, immutable");
    expect(res.headers["accept-ranges"]).toBe("bytes");
    expect(Number(res.headers["content-length"])).toBe(mp3.length);
  });

  it("answers a Range request with 206", async () => {
    const res = await request(createApp({ adhanDir: dir }))
      .get("/adhan/test/v1/regular.mp3")
      .set("Range", "bytes=0-99")
      .expect(206);
    expect(res.headers["content-range"]).toBe("bytes 0-99/1000");
    expect(Number(res.headers["content-length"])).toBe(100);
  });

  it("serves a caf as audio/x-caf", async () => {
    const res = await request(createApp({ adhanDir: dir })).get("/adhan/test/v1/regular_short.caf").expect(200);
    expect(res.headers["content-type"]).toBe("audio/x-caf");
  });

  it("404s a missing file", async () => {
    await request(createApp({ adhanDir: dir })).get("/adhan/test/v2/regular.mp3").expect(404);
  });
});
