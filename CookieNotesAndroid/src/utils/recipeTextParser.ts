export interface ParsedRecipeText {
  name: string;
  ingredients: string[];
  instructions: string[];
  notes: string;
  hasStructuredContent: boolean;
}

type ParseSection = 'preamble' | 'body' | 'ingredients' | 'instructions' | 'notes';

function headingForLine(line: string): ParseSection | null {
  const normalized = line
    .replace(/^[:\s]+|[:\s]+$/g, '')
    .toLowerCase();

  switch (normalized) {
    case 'ingredient':
    case 'ingredients':
    case 'ingrédient':
    case 'ingrédients':
    case 'ingrediente':
    case 'ingredientes':
      return 'ingredients';
    case 'instruction':
    case 'instructions':
    case 'direction':
    case 'directions':
    case 'method':
    case 'step':
    case 'steps':
    case 'préparation':
    case 'preparation':
    case 'étape':
    case 'étapes':
    case 'etape':
    case 'etapes':
    case 'méthode':
    case 'methode':
    case 'instrucción':
    case 'instruccion':
    case 'instrucciones':
    case 'preparación':
    case 'preparacion':
    case 'paso':
    case 'pasos':
    case 'método':
    case 'metodo':
      return 'instructions';
    case 'note':
    case 'notes':
    case 'tip':
    case 'tips':
    case 'astuce':
    case 'astuces':
    case 'conseil':
    case 'conseils':
    case 'nota':
    case 'notas':
    case 'consejo':
    case 'consejos':
      return 'notes';
    default:
      return null;
  }
}

function isBulletLine(line: string): boolean {
  return (
    line.startsWith('-') ||
    line.startsWith('*') ||
    line.startsWith('•') ||
    line.startsWith('–') ||
    line.startsWith('—')
  );
}

const NUMBERED_RE = /^\d+[.)]\s+/;

function isNumberedLine(line: string): boolean {
  return NUMBERED_RE.test(line);
}

function stripMarker(line: string): string {
  if (isNumberedLine(line)) {
    return line.replace(NUMBERED_RE, '').trim();
  }
  if (isBulletLine(line)) {
    return line.slice(1).trim();
  }
  return line;
}

function isWebURL(line: string): boolean {
  try {
    const parsed = new URL(line);
    const scheme = parsed.protocol.toLowerCase();
    return scheme === 'http:' || scheme === 'https:';
  } catch {
    return false;
  }
}

export function parseRecipeText(raw: string): ParsedRecipeText {
  const lines = raw
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  let name = '';
  const ingredients: string[] = [];
  const instructions: string[] = [];
  const notes: string[] = [];
  let section: ParseSection = 'preamble';
  let sawHeading = false;

  for (const line of lines) {
    if (isWebURL(line)) {
      continue;
    }

    const heading = headingForLine(line);
    if (heading) {
      sawHeading = true;
      section = heading;
      continue;
    }

    if (!name && section === 'preamble' && !isBulletLine(line) && !isNumberedLine(line)) {
      name = line;
      section = 'body';
      continue;
    }

    const cleaned = stripMarker(line);
    if (!cleaned) continue;

    switch (section) {
      case 'ingredients':
        ingredients.push(cleaned);
        break;
      case 'instructions':
        instructions.push(cleaned);
        break;
      case 'notes':
        notes.push(cleaned);
        break;
      case 'preamble':
      case 'body':
        if (isBulletLine(line)) {
          ingredients.push(cleaned);
        } else if (isNumberedLine(line)) {
          instructions.push(cleaned);
        } else {
          notes.push(cleaned);
        }
        break;
    }
  }

  return {
    name,
    ingredients,
    instructions,
    notes: notes.join('\n'),
    hasStructuredContent: sawHeading || ingredients.length > 0 || instructions.length > 0,
  };
}
