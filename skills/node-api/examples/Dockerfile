# apps/api/Dockerfile   (contexto de build: la raíz del repo)
# Targets: `api` (sirve), `migrator` (corre las migraciones una vez y termina). skill docker-ci, references/docker.md.
#
# La imagen base va UNA vez, con tag exacto y digest; los demás stages heredan de `base`.
#   por qué:  skill docker-ci, references/docker-base-stage.md y docker-pin-digest.md
#   digest:   docker buildx imagetools inspect node:<tag> | head -3   (el del índice multi-arch)
#   la mueve: Dependabot, skills/workflow/examples/github/dependabot.yml (docker-updates-bot.md)
#   tiene que coincidir con .nvmrc: ci.md lo verifica en el runner y en la imagen (docker-runtime-verified.md)
FROM node:24.22.1-alpine@sha256:06d7adf3e0ef61a13f1d28682726366f97a15aa1888c934d3ecec86c33918b53 AS base
WORKDIR /app

FROM base AS build
COPY package*.json ./
COPY apps/api/package.json apps/api/
COPY packages/contracts/package.json packages/contracts/
RUN npm ci
COPY . .
RUN npm run build -w packages/contracts -w apps/api

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=build /app/package*.json ./
COPY --from=build /app/apps/api/package.json apps/api/
COPY --from=build /app/packages/contracts/package.json packages/contracts/
RUN npm ci --omit=dev
COPY --from=build /app/apps/api/dist apps/api/dist
COPY --from=build /app/packages/contracts/dist packages/contracts/dist
USER node

FROM runtime AS migrator
# el script que corra las migraciones del ORM del stack. Sin comentario en la línea del CMD: con uno, Docker la lee en shell form
CMD ["npm", "run", "-w", "apps/api", "migrate"]

FROM runtime AS api
CMD ["node", "apps/api/dist/main.js"]
