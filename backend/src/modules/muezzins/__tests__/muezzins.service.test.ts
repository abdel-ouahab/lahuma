jest.mock("../../../config/prisma", () => ({ prisma: {} }));
jest.mock("../../../config/env", () => ({ env: { mediaBaseUrl: "https://cdn.example.com/" } }));

import { resolveMediaUrl, toDto } from "../muezzins.service";

describe("muezzin urls", () => {
  it("keeps absolute urls", () => {
    expect(resolveMediaUrl("https://other.example.com/a.mp3")).toBe(
      "https://other.example.com/a.mp3"
    );
  });

  it("prefixes relative urls with the media base", () => {
    expect(resolveMediaUrl("/adhan/x/regular.mp3")).toBe(
      "https://cdn.example.com/adhan/x/regular.mp3"
    );
  });

  it("resolves the import's versioned paths", () => {
    expect(resolveMediaUrl("/adhan/algeria/v2/fajr_short.caf", "http://10.0.2.2:4000")).toBe(
      "http://10.0.2.2:4000/adhan/algeria/v2/fajr_short.caf"
    );
  });

  it("maps every audio field and drops internal columns", () => {
    const dto = toDto({
      id: "1",
      nameAr: "مؤذن",
      nameFr: "Muezzin",
      country: "DZ",
      regularUrl: "/r.mp3",
      fajrUrl: "/f.mp3",
      regularShortUrl: "/r.caf",
      fajrShortUrl: "/f.caf",
      sortOrder: 2,
      version: 3,
      isActive: true,
    } as never);
    expect(dto.fajrShortUrl).toBe("https://cdn.example.com/f.caf");
    expect(dto.version).toBe(3);
    expect(dto).not.toHaveProperty("isActive");
  });
});
