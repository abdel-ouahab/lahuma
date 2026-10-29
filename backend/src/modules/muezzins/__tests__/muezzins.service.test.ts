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
