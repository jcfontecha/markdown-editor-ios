---
name: generate-workout-icons
description: Generate Kauch exercise and equipment icons with OpenAI image generation. Use when creating or refreshing workout artwork such as kettlebells, barbells, dumbbells, machines, or movement icons like push-ups, squats, and deadlifts, especially when the output should match Kauch's playful 3D style and BrandAccent color.
---

Generate icon prompts directly from the user request. Do not build prompts from templates in code. Treat the language model as the prompt engine and use this skill to keep output stylistically consistent with Kauch. Use the bundled script only as a thin transport layer for the OpenAI Images API.

## Prerequisite

- Treat `apps/web/.env.local` as the repo source of truth for `OPENAI_API_KEY`.
- If you return a runnable `curl`, make it explicit that the command requires `OPENAI_API_KEY` to be available in the shell environment. `apps/web/.env.local` does not get loaded into a shell automatically.
- When helpful, tell the user to export the key from `apps/web/.env.local` before running the request rather than inventing a different env file or secret location.
- Prefer a programmatic extraction step that reads `apps/web/.env.local` and exports `OPENAI_API_KEY` without printing the secret.

Use the bundled script by default. It reads `OPENAI_API_KEY` from the current shell if present, otherwise falls back to `apps/web/.env.local`.

If the user explicitly asks for raw shell commands, use this extraction command before any runnable `curl` example:

```bash
export OPENAI_API_KEY="$(
  python3 - <<'PY'
from pathlib import Path

for line in Path('apps/web/.env.local').read_text().splitlines():
    if line.startswith('OPENAI_API_KEY='):
        print(line.split('=', 1)[1].strip().strip('\"').strip(\"'\"), end='')
        break
else:
    raise SystemExit('OPENAI_API_KEY not found in apps/web/.env.local')
PY
)"
```

## Core Rules

- Keep the style direction consistent unless the user asks for a variation: minimalist but playful 3D icon, floating subject, about 45-degree angle, soft matte finish, clean studio lighting.
- Keep the request minimal: `model`, `prompt`, `n`, `size`, `quality`, `background`, and optionally `image[]` when using a reference subject image.
- Exercise icons must always use the local reference subject image and the `/v1/images/edits` path. Do not generate exercise icons from prompt-only requests.
- For exercise icons, use the reference subject image at `.agents/skills/generate-workout-icons/reference_subject.png` unless the user explicitly provides a different reference.
- Prefer resizing shipped app icons after generation. `512x512` is a good default for Kauch's single-raster asset setup and materially reduces bundle weight versus keeping every icon at `1024x1024`.
- Treat the canonical equipment prompt in this skill as the only base pattern for equipment icons. Keep it almost unchanged and swap only the equipment noun plus the minimal repeated wording needed.
- Treat the canonical reference-image exercise prompt in this skill as the only base pattern for exercise icons. Keep it almost unchanged and swap only the exercise name plus minimal equipment wording.
- Prefer a single clear subject.
- For equipment icons, render only the equipment unless the user asks for hands or a scene.
- For exercise icons, render the reference subject in the clearest canonical pose for the movement unless the user specifies a phase.
- Include negative constraints when useful: no text, no border, no watermark, no UI chrome.
- If the movement is ambiguous, resolve it in natural language from context or ask only if the pose choice would materially change the output.
- Do not add descriptors that change the subject identity or material appearance beyond the user-provided pattern. In particular, do not add phrases like `natural skin tone`, `clothes color`, or any other alternate body-color guidance for exercise icons.

## Workflow

1. Classify the request as `equipment` or `exercise`.
2. Write the prompt directly in natural language from the user request.
3. Keep the prompt compact and concrete. Avoid verbose art-director prose.
4. Prefer the bundled script for execution so the prompt stays authored by the model while request mechanics stay deterministic.
5. Emit either:
   - a script command the user can run,
   - a direct API call if they explicitly ask for `curl`, or
   - a final prompt they can paste into their own workflow,
   depending on what they asked for.
6. If the user is creating app assets, suggest a matching slug and `iconName` in the form `<slug>.icon`.

## Script Usage

Default command:

```bash
python3 .agents/skills/generate-workout-icons/scripts/generate_image.py \
  --prompt "a minimalist but playful 3d icon of a dumbbell. color should be black. metallic silver accents are acceptable. the dumbbell is floating, angled at 45. soft rounded shaping wherever applicable. matte finish. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame." \
  --n 2 \
  --max-dimension 512 \
  --output .artifacts/icons/kettlebell.png
```

Prompt from stdin:

```bash
cat <<'EOF' | python3 .agents/skills/generate-workout-icons/scripts/generate_image.py \
  --prompt-stdin \
  --n 2 \
  --max-dimension 512 \
  --output .artifacts/icons/dumbbell.png
a minimalist but playful 3d icon of a dumbbell. color should be black. metallic silver accents are acceptable. the dumbbell is floating, angled at 45. soft rounded shaping wherever applicable. matte finish. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame.
EOF
```

Reference image edit:

```bash
python3 .agents/skills/generate-workout-icons/scripts/generate_image.py \
  --image ".agents/skills/generate-workout-icons/reference_subject.png" \
  --prompt "a minimalist but playful 3d icon of a person doing a barbell back squat. person's color should be #6B9E00. angled at 45. soft matte finish. the equipment this person is using should be matte black. the pose should be an accurate representation of the exercise. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame." \
  --n 1 \
  --quality high \
  --max-dimension 512 \
  --background transparent \
  --moderation auto \
  --output .artifacts/icons/back-squat.png
```

For Xcode asset catalogs, prefer a single universal raster for these AI-generated PNG icons. Check in one `image.png` per `.imageset`, omit the scale field in `Contents.json`, and keep the raster itself reasonably sized instead of shipping separate `1x`, `2x`, and `3x` copies.

## Canonical Request Shape

Use this request shape unless the user asks for something else:

```json
{
  "model": "gpt-image-1-mini",
  "prompt": "<write this directly from the request>",
  "n": 1,
  "size": "1024x1024",
  "quality": "medium",
  "moderation": "auto"
}
```

## Good Prompt Characteristics

- Name the subject early.
- For equipment icons, keep the material and color guidance exactly aligned with the canonical equipment prompt.
- For exercise icons, keep the subject-color guidance exactly aligned with the canonical exercise prompt.
- Describe pose and orientation once.
- Keep finish and lighting concise.
- Prefer editing the canonical examples rather than inventing a new prompt shape.
- For exercise icons, stay anchored to the reference-image prompt structure.

## Examples

Canonical equipment prompt:

```text
a minimalist but playful 3d icon of a dumbbell. color should be black. metallic silver accents are acceptable. the dumbbell is floating, angled at 45. soft rounded shaping wherever applicable. matte finish. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame.
```

Use this almost as-is. Only swap the equipment noun and, if needed, the matching repeated noun in the second sentence.

Runnable equipment request with the script:

```bash
python3 .agents/skills/generate-workout-icons/scripts/generate_image.py \
  --prompt "a minimalist but playful 3d icon of a dumbbell. color should be black. metallic silver accents are acceptable. the dumbbell is floating, angled at 45. soft rounded shaping wherever applicable. matte finish. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame." \
  --n 2 \
  --max-dimension 512 \
  --output .artifacts/icons/dumbbell.png
```

Canonical exercise prompt:

```text
a minimalist but playful 3d icon of a person doing a barbell back squat. person's color should be #6B9E00. angled at 45. soft matte finish. the equipment this person is using should be matte black. the pose should be an accurate representation of the exercise. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame.
```

Use this almost as-is. Only swap the movement wording and make the smallest equipment adjustment needed for the specific exercise. Always send it with the reference subject image.

Runnable exercise request with the script:

```bash
python3 .agents/skills/generate-workout-icons/scripts/generate_image.py \
  --image ".agents/skills/generate-workout-icons/reference_subject.png" \
  --prompt "a minimalist but playful 3d icon of a person doing a push-up. person's color should be #6B9E00. angled at 45. soft matte finish. the pose should be an accurate representation of the exercise. soft uniform studio light. isometric-ish composition, maximizing space, fit to frame." \
  --max-dimension 512 \
  --quality high \
  --background transparent \
  --output .artifacts/icons/push-up.png
```

## Naming Guidance

- Prefer lowercase slugs derived from the subject.
- Recommended asset filename: `<slug>.png`
- Recommended app-facing icon name: `<slug>.icon`
- Examples:
  - `kettlebell.png` -> `kettlebell.icon`
  - `push-up.png` -> `push-up.icon`

## Output Preference

- If the user asks for "the prompt", return just the prompt.
- If the user asks for a runnable request, return the script command by default and `curl` only when explicitly requested.
- If the user asks for multiple variants, vary the pose or proportions slightly but keep the overall style stable.

## Minimal Adjustment Examples

- Equipment:
  - `dumbbell` -> `kettlebell`
  - `the dumbbell is floating` -> `the kettlebell is floating`
- Exercise:
  - `doing a barbell back squat` -> `doing a deadlift`
  - `the equipment this person is using should be matte black` -> `the dumbbells this person is carrying should be matte black`
  - remove the equipment sentence only when the exercise is purely bodyweight

Do not rewrite the whole prompt when these minimal substitutions are sufficient.
