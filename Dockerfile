# Stage 1: Build with Flutter SDK >=3.9.0
FROM cirrusci/flutter:3.22.0 AS builder
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
# If you have nginx.conf for SPA routing, uncomment the next line
# COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
