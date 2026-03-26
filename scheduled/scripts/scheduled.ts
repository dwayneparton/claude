import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync, unlinkSync, readdirSync } from "fs";
import { execSync, spawnSync } from "child_process";
import { resolve, dirname, basename } from "path";
import { homedir } from "os";
import YAML from "yaml";

const SCHEDULED_DIR = resolve(dirname(new URL(import.meta.url).pathname), "..");
const TASKS_DIR = resolve(SCHEDULED_DIR, "tasks");
const PLISTS_DIR = resolve(SCHEDULED_DIR, "plists");
const LOGS_DIR = resolve(SCHEDULED_DIR, "logs");
const LAUNCH_AGENTS_DIR = resolve(homedir(), "Library", "LaunchAgents");
const PLIST_PREFIX = "dev.claude.scheduled";

interface ScheduleEntry {
  Hour?: number;
  Minute?: number;
  Weekday?: number;
  Day?: number;
  Month?: number;
}

interface Task {
  name: string;
  description: string;
  working_directory: string;
  model: string;
  schedule: ScheduleEntry[];
  prompt: string;
}

function loadTask(filepath: string): Task {
  const content = readFileSync(filepath, "utf-8");
  return YAML.parse(content) as Task;
}

function toPlist(obj: Record<string, unknown>): string {
  const lines: string[] = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    '<plist version="1.0">',
  ];

  function serialize(value: unknown, indent: number): void {
    const pad = "  ".repeat(indent);
    if (typeof value === "string") {
      lines.push(`${pad}<string>${escapeXml(value)}</string>`);
    } else if (typeof value === "number" && Number.isInteger(value)) {
      lines.push(`${pad}<integer>${value}</integer>`);
    } else if (typeof value === "boolean") {
      lines.push(`${pad}<${value}/>`);
    } else if (Array.isArray(value)) {
      lines.push(`${pad}<array>`);
      for (const item of value) {
        serialize(item, indent + 1);
      }
      lines.push(`${pad}</array>`);
    } else if (typeof value === "object" && value !== null) {
      lines.push(`${pad}<dict>`);
      for (const [k, v] of Object.entries(value)) {
        lines.push(`${pad}  <key>${escapeXml(k)}</key>`);
        serialize(v, indent + 1);
      }
      lines.push(`${pad}</dict>`);
    }
  }

  function escapeXml(s: string): string {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  serialize(obj, 0);
  lines.push("</plist>");
  return lines.join("\n") + "\n";
}

function generatePlist(taskName: string, task: Task): string {
  const runScript = resolve(SCHEDULED_DIR, "scripts", "run-task.sh");

  const plist: Record<string, unknown> = {
    Label: `${PLIST_PREFIX}.${taskName}`,
    ProgramArguments: ["/bin/bash", runScript, taskName],
    StandardOutPath: resolve(LOGS_DIR, `${taskName}.out.log`),
    StandardErrorPath: resolve(LOGS_DIR, `${taskName}.err.log`),
  };

  const schedule = task.schedule ?? [];
  if (schedule.length === 1) {
    plist.StartCalendarInterval = schedule[0];
  } else if (schedule.length > 1) {
    plist.StartCalendarInterval = schedule;
  }

  return toPlist(plist);
}

function install(): void {
  mkdirSync(PLISTS_DIR, { recursive: true });
  mkdirSync(LOGS_DIR, { recursive: true });
  mkdirSync(LAUNCH_AGENTS_DIR, { recursive: true });

  const taskFiles = readdirSync(TASKS_DIR).filter(
    (f) => f.endsWith(".yaml") || f.endsWith(".yml")
  );

  if (taskFiles.length === 0) {
    console.log("No tasks found in tasks/");
    return;
  }

  for (const file of taskFiles) {
    const taskName = basename(file, file.endsWith(".yaml") ? ".yaml" : ".yml");
    const task = loadTask(resolve(TASKS_DIR, file));
    const plistXml = generatePlist(taskName, task);

    const plistPath = resolve(PLISTS_DIR, `${PLIST_PREFIX}.${taskName}.plist`);
    writeFileSync(plistPath, plistXml);

    const dest = resolve(LAUNCH_AGENTS_DIR, `${PLIST_PREFIX}.${taskName}.plist`);

    // Unload if already loaded
    try {
      execSync(`launchctl unload "${dest}" 2>/dev/null`);
    } catch {
      // Not loaded, that's fine
    }

    copyFileSync(plistPath, dest);

    try {
      execSync(`launchctl load "${dest}"`);
      console.log(`  Installed: ${taskName}`);
    } catch (err) {
      console.error(`  Failed: ${taskName} — ${err}`);
    }
  }

  console.log(`\n${taskFiles.length} task(s) installed.`);
}

function uninstall(): void {
  let removed = 0;

  try {
    const files = readdirSync(LAUNCH_AGENTS_DIR).filter((f) =>
      f.startsWith(`${PLIST_PREFIX}.`)
    );

    for (const file of files) {
      const fullPath = resolve(LAUNCH_AGENTS_DIR, file);
      try {
        execSync(`launchctl unload "${fullPath}" 2>/dev/null`);
      } catch {
        // Already unloaded
      }
      unlinkSync(fullPath);
      console.log(`  Removed: ${file}`);
      removed++;
    }
  } catch {
    // Directory might not exist
  }

  if (removed === 0) {
    console.log("No scheduled tasks installed.");
  } else {
    console.log(`\n${removed} task(s) removed.`);
  }
}

function run(taskName: string): void {
  const taskFile = [
    resolve(TASKS_DIR, `${taskName}.yaml`),
    resolve(TASKS_DIR, `${taskName}.yml`),
  ].find((f) => existsSync(f));

  if (!taskFile) {
    console.error(`Task not found: ${taskName}`);
    process.exit(1);
  }

  const task = loadTask(taskFile);
  const workingDir = task.working_directory?.replace(/^~/, homedir()) ?? SCHEDULED_DIR;
  const model = task.model ?? "sonnet";
  const prompt = task.prompt ?? "";

  const now = new Date().toISOString();
  console.log(`[${now}] Starting task: ${taskName}`);

  const result = spawnSync("claude", ["-p", "--model", model, prompt], {
    cwd: workingDir,
    stdio: "inherit",
  });

  if (result.error) {
    console.error(`Task error: ${result.error.message}`);
  }

  console.log(`[${new Date().toISOString()}] Finished task: ${taskName}`);
}

function list(): void {
  try {
    const output = execSync("launchctl list", { encoding: "utf-8" });
    const lines = output.split("\n").filter((l) => l.includes(PLIST_PREFIX));

    if (lines.length === 0) {
      console.log("No scheduled tasks currently loaded.");
      return;
    }

    console.log(`${"PID".padEnd(8)} ${"Status".padEnd(8)} Label`);
    console.log("-".repeat(50));
    for (const line of lines) {
      console.log(line);
    }
  } catch {
    console.log("Failed to query launchctl.");
  }
}

// CLI
const [, , command, ...args] = process.argv;

switch (command) {
  case "install":
    install();
    break;
  case "uninstall":
    uninstall();
    break;
  case "run":
    if (!args[0]) {
      console.error("Usage: scheduled.ts run <task-name>");
      process.exit(1);
    }
    run(args[0]);
    break;
  case "list":
    list();
    break;
  default:
    console.log("Usage: scheduled.ts [install|uninstall|run <task>|list]");
    process.exit(1);
}
