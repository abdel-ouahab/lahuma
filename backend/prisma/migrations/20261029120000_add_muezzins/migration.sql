-- CreateTable
CREATE TABLE "Muezzin" (
    "id" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameFr" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "regularUrl" TEXT NOT NULL,
    "fajrUrl" TEXT NOT NULL,
    "regularShortUrl" TEXT NOT NULL,
    "fajrShortUrl" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Muezzin_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Muezzin_isActive_sortOrder_idx" ON "Muezzin"("isActive", "sortOrder");
