-- CreateTable
CREATE TABLE "Link" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "targetUrl" TEXT NOT NULL
);

-- CreateIndex
CREATE UNIQUE INDEX "Link_id_key" ON "Link"("id");
