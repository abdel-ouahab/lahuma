// Placeholder muezzins for development. Upload the matching files to the
// bucket under MEDIA_BASE_URL (see docs/adhan.md), or edit the URLs.
// Run with `npx prisma db seed`; safe to re-run (upserts by id).
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const muezzins = [
  { slug: "makkah", nameAr: "أذان الحرم المكي", nameFr: "Adhan de La Mecque", country: "SA" },
  { slug: "madinah", nameAr: "أذان المسجد النبوي", nameFr: "Adhan de Médine", country: "SA" },
  { slug: "algiers", nameAr: "أذان جامع الجزائر", nameFr: "Adhan de Djamaâ El Djazaïr", country: "DZ" },
];

async function main() {
  for (const [i, m] of muezzins.entries()) {
    const id = `00000000-0000-4000-8000-00000000000${i + 1}`;
    const base = `/adhan/${m.slug}`;
    const data = {
      nameAr: m.nameAr,
      nameFr: m.nameFr,
      country: m.country,
      regularUrl: `${base}/regular.mp3`,
      fajrUrl: `${base}/fajr.mp3`,
      regularShortUrl: `${base}/regular_short.caf`,
      fajrShortUrl: `${base}/fajr_short.caf`,
      isActive: true,
      sortOrder: i,
    };
    await prisma.muezzin.upsert({ where: { id }, update: data, create: { id, ...data } });
  }
  console.log(`Seeded ${muezzins.length} muezzins.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
