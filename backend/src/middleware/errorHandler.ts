import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { AppError } from "../utils/AppError";

// Never leak internal/technical errors to clients.
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ error: err.message });
  }

  // A request body that failed its schema is the client's mistake, not ours:
  // answer 400 with the first problem so forms can show it.
  if (err instanceof ZodError) {
    const issue = err.issues[0];
    const field = issue?.path.join(".");
    const message = issue
      ? issue.code === "invalid_type" && issue.received === "undefined"
        ? `${field} is required.`
        : field && !issue.message.includes(field)
          ? `${field}: ${issue.message}`
          : issue.message
      : "Invalid request.";
    return res.status(400).json({ error: message });
  }

  // express.json() on malformed JSON or a body over its size limit.
  const status = (err as { status?: number; type?: string } | null)?.status;
  if (status === 400 || status === 413) {
    return res.status(status).json({ error: status === 413 ? "Request body is too large." : "Malformed request body." });
  }

  console.error(err);
  return res.status(500).json({ error: "Something went wrong. Please try again." });
}
