interface CompanyContextSection {
  category: string;
  content: string;
}

export function formatCompanyBriefing(
  summary: string,
  contexts: CompanyContextSection[],
  maxChars: number,
): string {
  const sections = [
    `Overview: ${summary}`,
    ...contexts.map((context) => `${context.category}: ${context.content}`),
  ];

  return sections.join('\n').slice(0, maxChars);
}
