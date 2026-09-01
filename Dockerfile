FROM nginx:alpine
COPY build/web /usr/share/nginx/html
# If you have nginx.conf for SPA routing, uncomment the next line:
# COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
