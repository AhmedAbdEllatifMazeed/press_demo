# Dockerfile
FROM nginx:1.19

# Copy your custom entrypoint and template
COPY resources/nginx-entrypoint.sh /usr/local/bin/
COPY resources/nginx.template /templates/nginx/frappe.conf.template


ENTRYPOINT ["nginx-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
