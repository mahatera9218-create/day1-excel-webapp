/**
 * 마이그레이션 러너 (최소). DATABASE_URL 필요.
 * 사용: DATABASE_URL=postgres://... npm run db:migrate
 * 프로덕션은 전용 마이그레이션 도구(node-pg-migrate 등) 도입 권장.
 */
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "pg";

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(__dirname, "..", "db", "migrations");

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL 가 필요합니다.");
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    const files = readdirSync(migrationsDir).filter((f) => f.endsWith(".sql")).sort();
    for (const f of files) {
      console.log(`applying ${f}`);
      await client.query(readFileSync(join(migrationsDir, f), "utf8"));
    }
    console.log("migrations done");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
