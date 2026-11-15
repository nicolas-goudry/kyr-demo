import Fastify from "fastify";
import { Pool } from "pg";
import { execFile } from "node:child_process";
import { access } from "node:fs/promises";
import process from "node:process";
import { promisify } from "node:util";

const nodeMajor = process.versions.node.split(".").map(Number)[0];
if (nodeMajor < 24) {
  console.error(`Unsupported Node.js version runtime. Node.js version 24 or more is required (current is Node.js ${nodeMajor}).`)
  process.exit(1)
}

const fastify = Fastify({ logger: true });
// We use execFile over exec to prevent shell-injection vulnerabilities with paths
const execFileAsync = promisify(execFile);

/*
 * Database Configuration
 *
 * The `pg` library automatically uses standard environment variables:
 * PGUSER, PGHOST, PGPASSWORD, PGDATABASE, PGPORT
 */
const pool = new Pool();

/*
 * Check that the database is up and running
 */
fastify.get("/health", async (request, reply) => {
  try {
    await pool.query("SELECT 1 AS status");

    return reply.code(200).send({
      status: "ok",
      message: "Database is up and running",
    });
  } catch (error) {
    request.log.error("Health check failed: DB down", error);

    return reply.code(503).send({
      status: "error",
      message: "Database is unreachable",
    });
  }
});

/*
 * Lists all stored analysis records
 */
fastify.get('/analyses', async (request, reply) => {
  try {
    const query = 'SELECT * FROM media_metadata ORDER BY created_at DESC;';
    const result = await pool.query(query);

    return reply.code(200).send({
      count: result.rowCount,
      data: result.rows
    });
  } catch (error) {
    request.log.error('Failed to retrieve analyses', error);

    return reply.code(500).send({
      error: 'Failed to retrieve analyses from the database.'
    });
  }
});

/*
 * Analyse a media file, stores metadata, and returns it
 */
fastify.post("/analyze", async (request, reply) => {
  const { path: filePath } = request.body || {};

  if (!filePath || typeof filePath !== "string") {
    return reply.code(400).send({
      error: 'Please provide a valid "path" attribute in the JSON body.',
    });
  }

  try {
    await access(filePath);
  } catch (err) {
    return reply
      .code(404)
      .send({ error: `File not found at path: ${filePath}` });
  }

  let ffprobeData;
  let stdout;

  try {
    const result = await execFileAsync("ffprobe", [
      "-v",
      "quiet",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      filePath,
    ]);

    stdout = result.stdout;
  } catch (error) {
    request.log.error("ffprobe execution failed", error);

    return reply.code(500).send({
      error:
        "Failed to extract metadata. Ensure ffprobe is installed and the file is a valid media file.",
    });
  }

  try {
    ffprobeData = JSON.parse(stdout);

    const format = ffprobeData.format || {};
    const stream =
      ffprobeData.streams && ffprobeData.streams.length > 0
        ? ffprobeData.streams[0]
        : {};

    const duration = format.duration ? parseFloat(format.duration) : null;
    const bitrate = format.bit_rate ? parseInt(format.bit_rate, 10) : null;
    const codec = stream.codec_name || null;

    const query = `
        INSERT INTO media_metadata (file_path, duration, codec, bitrate)
        VALUES ($1, $2, $3, $4)
        RETURNING *;
      `;
    const values = [filePath, duration, codec, bitrate];

    const dbResult = await pool.query(query, values);
    const savedRecord = dbResult.rows[0];

    return reply.code(200).send({
      message: "Analysis complete and stored in database successfully",
      data: savedRecord,
    });
  } catch (error) {
    request.log.error("Failed to parse ffprobe output or save to DB", error);

    return reply.code(500).send({
      error:
        "An error occurred while processing the metadata or saving to the database.",
    });
  }
});

const start = async () => {
  try {
    const port = process.env.PORT || 3000;

    await fastify.listen({ port: port, host: "127.0.0.1" });

    fastify.log.info(`Server listening on port ${port}`);
  } catch (err) {
    fastify.log.error(err);

    process.exit(1);
  }
};

start();

process.on("SIGINT", async () => {
  fastify.log.info("Shutting down...");

  await pool.end();

  process.exit(0);
});
