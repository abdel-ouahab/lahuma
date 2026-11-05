// Muezzins from prisma/data/muezzins.json, the manifest `npm run adhan:import`
// fills in (see docs/adhan.md). Run the import first, then
// `npx prisma db seed`; safe to re-run (upserts by fixed id).
import { PrismaClient } from "@prisma/client";
import { loadManifest, seedRows } from "../src/modules/muezzins/muezzins.manifest";

const prisma = new PrismaClient();

async function main() {
  const rows = seedRows(loadManifest());
  for (const { id, data } of rows) {
    await prisma.muezzin.upsert({ where: { id }, update: data, create: { id, ...data } });
  }
  const inactive = rows.filter((r) => !r.data.isActive).length;
  console.log(`Seeded ${rows.length} muezzins${inactive ? ` (${inactive} inactive: run npm run adhan:import)` : ""}.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
