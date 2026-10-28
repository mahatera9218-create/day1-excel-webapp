/**
 * 시드 러너 (최소). DATABASE_URL 필요. db/seed/*.sql 적용.
 * 사용: DATABASE_URL=postgres://... npm run db:seed
 */
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "pg";

const __dirname = dirname(fileURLToPath(import.meta.url));
const seedDir = join(__dirname, "..", "db", "seed");

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL 가 필요합니다.");
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    const files = readdirSync(seedDir).filter((f) => f.endsWith(".sql")).sort();
    for (const f of files) {
      console.log(`seeding ${f}`);
      await client.query(readFileSync(join(seedDir, f), "utf8"));
    }
    console.log("seed done");
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
