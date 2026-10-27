-- CreateTable
CREATE TABLE "Reciter" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "slug" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Reciter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReciterSurah" (
    "id" TEXT NOT NULL,
    "reciterId" TEXT NOT NULL,
    "surahNumber" INTEGER NOT NULL,
    "audioPath" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReciterSurah_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Reciter_slug_key" ON "Reciter"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "ReciterSurah_reciterId_surahNumber_key" ON "ReciterSurah"("reciterId", "surahNumber");

-- AddForeignKey
ALTER TABLE "ReciterSurah" ADD CONSTRAINT "ReciterSurah_reciterId_fkey" FOREIGN KEY ("reciterId") REFERENCES "Reciter"("id") ON DELETE CASCADE ON UPDATE CASCADE;
