FROM ghcr.io/cirruslabs/flutter:3.44.5 AS build
WORKDIR /app
COPY . .
ARG API_BASE
RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE=${API_BASE}

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
EXPOSE 80
