import { spawnSync } from "child_process";
import { createHash } from "crypto";
import fs from "fs";
import path from "path";

// Downloads each muezzin's adhans from the pinned source commit, then trims,
// normalises and encodes them into public/adhan/<slug>/v<version>/:
//   npm run adhan:import                  # every muezzin in the manifest
//   npm run adhan:import -- --only algeria
//   npm run adhan:import -- --force       # reprocess even if unchanged
// Idempotent: a muezzin whose sources, pipeline and outputs are unchanged is
// skipped. When an output's bytes change, its `version` is bumped, so the
// app downloads it again (see docs/adhan.md). Needs ffmpeg and ffprobe on
// PATH, or FFMPEG_PATH / FFPROBE_PATH.

const BACKEND = path.resolve(__dirname, "../..");
const MANIFEST = path.join(BACKEND, "prisma/data/muezzins.json");
const SRC_DIR = path.join(BACKEND, "media-src/adhan");
const PUBLIC_DIR = path.join(BACKEND, "public/adhan");

const MIN_SECONDS = 60;
const MAX_SECONDS = 6 * 60;
const SHORT_SECONDS = 29.5; // iOS ignores a notification sound over 30 s

// Every processing setting. Changing one changes PIPELINE_ID, which
// reprocesses every muezzin on the next run.
const PARAMS = {
  silence: "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.1,areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.3,areverse",
  loudnorm: "I=-16:TP=-1.5:LRA=11",
  fadeIn: 0.3,
  fadeOut: 1.5,
  mp3: { sampleRate: 44100, bitrate: "96k" },
  short: { seconds: SHORT_SECONDS, fadeOut: 2, sampleRate: 22050, codec: "adpcm_ima_qt" },
};
const PIPELINE_ID = createHash("sha256").update(JSON.stringify(PARAMS)).digest("hex").slice(0, 12);

type SourceKind = "regular" | "fajr";
type OutputKind = "regular" | "fajr" | "regularShort" | "fajrShort";

const OUTPUT_FILES: Record<OutputKind, string> = {
  regular: "regular.mp3",
  fajr: "fajr.mp3",
  regularShort: "regular_short.caf",
  fajrShort: "fajr_short.caf",
};

type Probe = { durationSec: number; bitRate: number; sampleRate: number; channels: number; codec: string };
type SourceInfo = Probe & { file: string; sha256: string; bytes: number };
type OutputInfo = { path: string; sha256: string; bytes: number; durationSec: number };

export type ManifestRow = {
  slug: string;
  id: string;
  nameAr: string;
  nameFr: string;
  country: string;
  sortOrder: number;
  version: number;
  isActive: boolean;
  allowShort?: boolean;
  source: { repo: string; commit: string; regularFile: string; fajrFile: string };
  // Written by this script:
  status?: "ok" | "short" | "failed";
  warnings?: string[];
  pipeline?: string;
  sources?: Partial<Record<SourceKind, SourceInfo>>;
  outputs?: Partial<Record<OutputKind, OutputInfo>>;
};

type Manifest = { $comment?: string; muezzins: ManifestRow[] };

// ---------------------------------------------------------------- tools

function tool(name: "ffmpeg" | "ffprobe"): string {
  const fromEnv =
    name === "ffmpeg"
      ? process.env.FFMPEG_PATH
      : process.env.FFPROBE_PATH ??
        (process.env.FFMPEG_PATH &&
          path.join(path.dirname(process.env.FFMPEG_PATH), path.basename(process.env.FFMPEG_PATH).replace(/ffmpeg/i, "ffprobe")));
  const bin = fromEnv || name;
  const check = spawnSync(bin, ["-version"], { encoding: "utf8" });
  if (check.error || check.status !== 0) {
    throw new Error(
      `${name} not found (tried "${bin}"). Install ffmpeg (Windows: winget install Gyan.FFmpeg, ` +
        `macOS: brew install ffmpeg, Debian: apt install ffmpeg) or set FFMPEG_PATH / FFPROBE_PATH.`
    );
  }
  return bin;
}

function run(bin: string, args: string[]): string {
  const res = spawnSync(bin, args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (res.error) throw res.error;
  if (res.status !== 0) {
    const tail = (res.stderr || "").trim().split("\n").slice(-8).join("\n");
    throw new Error(`${path.basename(bin)} failed (exit ${res.status}):\n${tail}`);
  }
  return res.stderr || "";
}

function sha256(file: string): string {
  return createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function probe(ffprobe: string, file: string): Probe {
  const res = spawnSync(
    ffprobe,
    ["-v", "error", "-select_streams", "a:0", "-show_entries",
      "format=duration,bit_rate:stream=codec_name,sample_rate,channels", "-of", "json", file],
    { encoding: "utf8" }
  );
  if (res.status !== 0) throw new Error(`ffprobe could not read ${file}: ${res.stderr}`);
  const json = JSON.parse(res.stdout);
  const stream = json.streams?.[0];
  if (!stream) throw new Error(`No audio stream in ${file}`);
  return {
    durationSec: round(Number(json.format.duration)),
    bitRate: Number(json.format.bit_rate) || 0,
    sampleRate: Number(stream.sample_rate),
    channels: Number(stream.channels),
    codec: stream.codec_name,
  };
}

const round = (n: number, digits = 2) => Math.round(n * 10 ** digits) / 10 ** digits;

// ---------------------------------------------------------------- download

function sourceUrls(row: ManifestRow, file: string): string[] {
  const { repo, commit } = row.source;
  const name = encodeURIComponent(file);
  return [
    `https://raw.githubusercontent.com/${repo}/${commit}/${name}`,
    `https://cdn.jsdelivr.net/gh/${repo}@${commit}/${name}`,
  ];
}

async function download(urls: string[], dest: string): Promise<void> {
  const errors: string[] = [];
  for (let attempt = 1; attempt <= 3; attempt++) {
    for (const url of urls) {
      try {
        const res = await fetch(url, { signal: AbortSignal.timeout(60_000) });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const type = res.headers.get("content-type") ?? "";
        if (!type.startsWith("audio/")) throw new Error(`content-type ${type || "missing"}`);
        const body = Buffer.from(await res.arrayBuffer());
        if (body.length === 0) throw new Error("empty body");
        fs.writeFileSync(`${dest}.part`, body);
        fs.renameSync(`${dest}.part`, dest);
        return;
      } catch (err) {
        errors.push(`${new URL(url).host} #${attempt}: ${(err as Error).message}`);
      }
    }
    await new Promise((r) => setTimeout(r, 1000 * attempt));
  }
  throw new Error(`Download failed:\n  ${errors.join("\n  ")}`);
}

// ---------------------------------------------------------------- processing

/** Two-pass loudnorm: the measurement of [input]. */
function measureLoudness(ffmpeg: string, input: string) {
  const log = run(ffmpeg, ["-hide_banner", "-nostdin", "-i", input,
    "-af", `loudnorm=${PARAMS.loudnorm}:print_format=json`, "-f", "null", "-"]);
  const json = log.slice(log.lastIndexOf("{"), log.lastIndexOf("}") + 1);
  const m = JSON.parse(json);
  if (!Number.isFinite(Number(m.input_i))) throw new Error(`${input} is silent`);
  return m as { input_i: string; input_tp: string; input_lra: string; input_thresh: string; target_offset: string };
}

/** Source mp3 → full mp3 and ≤ 29.5 s caf in [workDir], named for [kind]. */
function processOne(ffmpeg: string, ffprobe: string, src: string, workDir: string, kind: SourceKind) {
  const bitexact = ["-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1"];
  const trimmed = path.join(workDir, `${kind}.trimmed.wav`);
  const norm = path.join(workDir, `${kind}.norm.wav`);
  const full = path.join(workDir, OUTPUT_FILES[kind]);
  const short = path.join(workDir, OUTPUT_FILES[kind === "fajr" ? "fajrShort" : "regularShort"]);

  // A. Leading and trailing silence only; the pauses between phrases stay.
  run(ffmpeg, ["-hide_banner", "-nostdin", "-y", "-i", src, "-af", PARAMS.silence,
    "-ac", "1", "-ar", String(PARAMS.mp3.sampleRate), "-c:a", "pcm_s16le", ...bitexact, trimmed]);

  // B + C. Loudness to −16 LUFS / −1.5 dBTP, back to 44.1 kHz, fade in.
  const m = measureLoudness(ffmpeg, trimmed);
  const loudnorm =
    `loudnorm=${PARAMS.loudnorm}:measured_I=${m.input_i}:measured_TP=${m.input_tp}` +
    `:measured_LRA=${m.input_lra}:measured_thresh=${m.input_thresh}:offset=${m.target_offset}:linear=true`;
  run(ffmpeg, ["-hide_banner", "-nostdin", "-y", "-i", trimmed,
    "-af", `${loudnorm},aresample=${PARAMS.mp3.sampleRate},afade=t=in:d=${PARAMS.fadeIn}`,
    "-ac", "1", "-c:a", "pcm_s16le", ...bitexact, norm]);
  const d = probe(ffprobe, norm).durationSec;

  // D. Full file, faded out.
  run(ffmpeg, ["-hide_banner", "-nostdin", "-y", "-i", norm,
    "-af", `afade=t=out:st=${round(Math.max(0, d - PARAMS.fadeOut), 3)}:d=${PARAMS.fadeOut}`,
    "-c:a", "libmp3lame", "-b:a", PARAMS.mp3.bitrate, ...bitexact, full]);

  // E. iOS notification clip: IMA4 CAF, like ios/Runner/adhan_default_regular.caf.
  const t = Math.min(PARAMS.short.seconds, d);
  run(ffmpeg, ["-hide_banner", "-nostdin", "-y", "-i", norm, "-t", String(t),
    "-af", `afade=t=out:st=${round(Math.max(0, t - PARAMS.short.fadeOut), 3)}:d=${PARAMS.short.fadeOut},aresample=${PARAMS.short.sampleRate}`,
    "-ac", "1", "-c:a", PARAMS.short.codec, "-f", "caf", ...bitexact, short]);

  fs.rmSync(trimmed, { force: true });
  fs.rmSync(norm, { force: true });
}

// ---------------------------------------------------------------- main

type Line = { slug: string; file: string; from: string; to: string; size: string; warnings: string };

async function importRow(row: ManifestRow, ffmpeg: string, ffprobe: string, force: boolean, lines: Line[]) {
  const warnings: string[] = [];
  const srcDir = path.join(SRC_DIR, row.slug);
  fs.mkdirSync(srcDir, { recursive: true });

  // 1. Sources: downloaded once, kept in media-src/ (gitignored).
  const sources: Partial<Record<SourceKind, SourceInfo>> = {};
  for (const kind of ["regular", "fajr"] as const) {
    const file = kind === "regular" ? row.source.regularFile : row.source.fajrFile;
    const dest = path.join(srcDir, `${kind}.src.mp3`);
    const known = row.sources?.[kind];
    const stale = !fs.existsSync(dest) || known?.file !== file || (known && sha256(dest) !== known.sha256);
    if (stale) {
      console.log(`  ↓ ${row.slug}/${kind}: ${file}`);
      await download(sourceUrls(row, file), dest);
    }
    const p = probe(ffprobe, dest);
    if (p.durationSec < MIN_SECONDS) warnings.push(`${kind}: ${p.durationSec}s, probable clip`);
    if (p.durationSec > MAX_SECONDS) warnings.push(`${kind}: ${p.durationSec}s, over 6 min`);
    if (p.bitRate && p.bitRate < 32_000) warnings.push(`${kind}: low-quality source (${Math.round(p.bitRate / 1000)} kbps, ${p.sampleRate} Hz)`);
    sources[kind] = { file, sha256: sha256(dest), bytes: fs.statSync(dest).size, ...p };
  }
  const short = Object.values(sources).some((s) => s!.durationSec < MIN_SECONDS);
  if (short && !row.allowShort) warnings.push('not seeded until the manifest says "allowShort": true');

  // 2. Skip when nothing changed.
  const outputsOk =
    row.outputs &&
    (Object.keys(OUTPUT_FILES) as OutputKind[]).every((k) => {
      const o = row.outputs![k];
      const file = o && path.join(BACKEND, "public", o.path);
      return file && fs.existsSync(file) && sha256(file) === o.sha256;
    });
  const sourcesSame = (["regular", "fajr"] as const).every((k) => row.sources?.[k]?.sha256 === sources[k]!.sha256);
  if (!force && outputsOk && sourcesSame && row.pipeline === PIPELINE_ID) {
    row.status = short && !row.allowShort ? "short" : "ok";
    row.warnings = warnings;
    report(row, lines, "unchanged");
    return;
  }

  // 3. Process into a work dir, then publish under v<version>.
  const workDir = path.join(srcDir, "work");
  fs.rmSync(workDir, { recursive: true, force: true });
  fs.mkdirSync(workDir, { recursive: true });
  console.log(`  ⚙ ${row.slug}: processing`);
  processOne(ffmpeg, ffprobe, path.join(srcDir, "regular.src.mp3"), workDir, "regular");
  processOne(ffmpeg, ffprobe, path.join(srcDir, "fajr.src.mp3"), workDir, "fajr");

  const hashes = Object.fromEntries(
    (Object.keys(OUTPUT_FILES) as OutputKind[]).map((k) => [k, sha256(path.join(workDir, OUTPUT_FILES[k]))])
  ) as Record<OutputKind, string>;
  const changed = row.outputs && (Object.keys(OUTPUT_FILES) as OutputKind[]).some((k) => row.outputs![k]?.sha256 !== hashes[k]);
  if (changed) {
    row.version += 1;
    warnings.push(`files changed: version → ${row.version}`);
  }

  const slugDir = path.join(PUBLIC_DIR, row.slug);
  const target = path.join(slugDir, `v${row.version}`);
  fs.rmSync(slugDir, { recursive: true, force: true }); // older versions too
  fs.mkdirSync(target, { recursive: true });
  const outputs: Partial<Record<OutputKind, OutputInfo>> = {};
  for (const k of Object.keys(OUTPUT_FILES) as OutputKind[]) {
    const file = path.join(target, OUTPUT_FILES[k]);
    fs.copyFileSync(path.join(workDir, OUTPUT_FILES[k]), file);
    const durationSec = probe(ffprobe, file).durationSec;
    if (k.endsWith("Short") && durationSec > 30) throw new Error(`${OUTPUT_FILES[k]} is ${durationSec}s, over iOS's 30 s`);
    outputs[k] = {
      path: `/adhan/${row.slug}/v${row.version}/${OUTPUT_FILES[k]}`,
      sha256: hashes[k],
      bytes: fs.statSync(file).size,
      durationSec,
    };
  }
  fs.rmSync(workDir, { recursive: true, force: true });

  row.sources = sources;
  row.outputs = outputs;
  row.pipeline = PIPELINE_ID;
  row.status = short && !row.allowShort ? "short" : "ok";
  row.warnings = warnings;
  report(row, lines, "processed");
}

function report(row: ManifestRow, lines: Line[], state: string) {
  const mb = (b: number) => `${(b / 1e6).toFixed(2)} MB`;
  for (const k of Object.keys(OUTPUT_FILES) as OutputKind[]) {
    const o = row.outputs?.[k];
    const s = row.sources?.[k.startsWith("fajr") ? "fajr" : "regular"];
    lines.push({
      slug: k === "regular" ? `${row.slug} (${state})` : "",
      file: OUTPUT_FILES[k],
      from: s ? `${s.durationSec}s` : "?",
      to: o ? `${o.durationSec}s` : "?",
      size: o ? mb(o.bytes) : "?",
      warnings: k === "regular" ? (row.warnings ?? []).join("; ") : "",
    });
  }
}

function printTable(lines: Line[]) {
  const cols: (keyof Line)[] = ["slug", "file", "from", "to", "size", "warnings"];
  const head: Line = { slug: "slug", file: "file", from: "source", to: "output", size: "size", warnings: "warnings" };
  const width = (c: keyof Line) => Math.max(...[head, ...lines].map((l) => l[c].length));
  const fmt = (l: Line) => cols.map((c) => l[c].padEnd(width(c))).join("  ").trimEnd();
  console.log("\n" + fmt(head));
  console.log(cols.map((c) => "-".repeat(width(c))).join("  "));
  lines.forEach((l) => console.log(fmt(l)));
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes("--force");
  const only = args.includes("--only") ? args[args.indexOf("--only") + 1] : undefined;

  const ffmpeg = tool("ffmpeg");
  const ffprobe = tool("ffprobe");
  const manifest: Manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
  const rows = manifest.muezzins.filter((r) => !only || r.slug === only);
  if (only && rows.length === 0) throw new Error(`No muezzin "${only}" in ${MANIFEST}`);

  const lines: Line[] = [];
  let failed = 0;
  for (const row of rows) {
    console.log(`• ${row.slug}`);
    try {
      await importRow(row, ffmpeg, ffprobe, force, lines);
    } catch (err) {
      failed++;
      row.status = "failed";
      row.warnings = [(err as Error).message.split("\n")[0]];
      console.error(`  ✗ ${row.slug}: ${(err as Error).message}`);
      report(row, lines, "FAILED");
    }
    // Saved after each row, so an interrupted run keeps what it finished.
    fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + "\n");
  }

  printTable(lines);
  const total = manifest.muezzins
    .flatMap((r) => Object.values(r.outputs ?? {}))
    .reduce((sum, o) => sum + (o?.bytes ?? 0), 0);
  console.log(`\nTotal in public/adhan: ${(total / 1e6).toFixed(1)} MB · pipeline ${PIPELINE_ID}`);
  if (failed) process.exitCode = 1;
}

main().catch((err) => {
  console.error((err as Error).message);
  process.exitCode = 1;
});
