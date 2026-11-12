import { Role } from "@prisma/client";
import { prisma } from "../config/prisma";

// Promotes an existing account to ADMIN so it can use the admin panel:
//   npm run make-admin -- someone@example.com
async function main() {
  const email = process.argv[2]?.trim();
  if (!email) {
    console.error("Usage: npm run make-admin -- <email>");
    process.exitCode = 1;
    return;
  }

  const user = await prisma.user.findFirst({ where: { email: { equals: email, mode: "insensitive" } } });
  if (!user) {
    console.error(`No account with the email ${email}. Register it first.`);
    process.exitCode = 1;
    return;
  }

  await prisma.user.update({ where: { id: user.id }, data: { role: Role.ADMIN } });
  console.log(`${email} is now an admin.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
