-- CreateTable
CREATE TABLE "accounts" (
    "id" UUID NOT NULL,
    "username" VARCHAR(30) NOT NULL,
    "password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_rows" (
    "table_name" VARCHAR(40) NOT NULL,
    "id" VARCHAR(64) NOT NULL,
    "user_id" UUID NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "seq" BIGSERIAL NOT NULL,
    "data" JSONB NOT NULL,

    CONSTRAINT "sync_rows_pkey" PRIMARY KEY ("table_name","id")
);

-- CreateIndex
CREATE UNIQUE INDEX "accounts_username_key" ON "accounts"("username");

-- CreateIndex
CREATE INDEX "sync_rows_user_id_seq_idx" ON "sync_rows"("user_id", "seq");

-- AddForeignKey
ALTER TABLE "sync_rows" ADD CONSTRAINT "sync_rows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
