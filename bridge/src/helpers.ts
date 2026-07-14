import { get as httpGet } from "http";

export const fetchJson = (url: string): Promise<any> =>
  new Promise((resolve, reject) => {
    httpGet(url, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error("Failed to parse JSON response"));
        }
      });
    }).on("error", reject);
  });

export const formatRelativeTime = (ms: number): string => {
  const diffMs = Date.now() - ms;
  if (diffMs < 0) return "just now";
  const seconds = Math.floor(diffMs / 1000);
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hr ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} day${days > 1 ? "s" : ""} ago`;
  const weeks = Math.floor(days / 7);
  if (weeks < 5) return `${weeks} wk${weeks > 1 ? "s" : ""} ago`;
  const months = Math.floor(days / 30);
  if (months < 12) return `${months} mo ago`;
  const years = Math.floor(days / 365);
  return `${years} yr${years > 1 ? "s" : ""} ago`;
};

export const formatToolDesc = (
  tool: string,
  input: any,
  status: string,
): string => {
  const action =
    status === "error" ? "\u2717 " : status === "running" ? "" : "\u2713 ";
  if (!input || typeof input !== "object")
    return `${action}${tool} (${status})`;
  switch (tool) {
    case "bash":
    case "shell":
      return (
        action +
        (typeof input.command === "string"
          ? input.command
          : `${tool} (${status})`)
      );
    case "write":
    case "edit":
      return (
        action +
        (typeof input.filePath === "string"
          ? `\u270E ${input.filePath}`
          : `${tool} (${status})`)
      );
    case "read":
    case "glob":
    case "grep": {
      const p =
        typeof input.path === "string"
          ? input.path
          : typeof input.pattern === "string"
            ? input.pattern
            : typeof input.filePath === "string"
              ? input.filePath
              : "";
      return action + (p || `${tool} (${status})`);
    }
    case "webfetch":
      return (
        action +
        (typeof input.url === "string" ? input.url : `${tool} (${status})`)
      );
    default:
      return action + `${tool} (${status})`;
  }
};

export const extractToolContent = (
  tool: string,
  input: any,
  state: any,
): string | undefined => {
  if (!input) return undefined;
  switch (tool) {
    case "write":
      return typeof input.content === "string"
        ? input.content
        : typeof state?.output === "string"
          ? (state.output as string).slice(0, 500)
          : undefined;
    case "edit":
      return typeof input.newString === "string"
        ? input.newString
        : undefined;
    case "bash":
    case "shell":
      return typeof state?.output === "string"
        ? (state.output as string).slice(0, 500)
        : undefined;
    default:
      return typeof state?.output === "string"
        ? (state.output as string).slice(0, 500)
        : undefined;
  }
};
