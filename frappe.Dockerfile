FROM frappe/build:latest



# Initialize Bench with explicit Python version
RUN /home/frappe/.local/bin/bench init frappe-bench --skip-redis-config-generation


RUN cd frappe-bench && \
./env/bin/pip install gunicorn && \
/home/frappe/.local/bin/bench setup requirements

COPY common_site_config.json /home/frappe/frappe-bench/sites/common_site_config.json

EXPOSE 8000 9000 2200 8088

CMD [ \
  "/home/frappe/frappe-bench/env/bin/gunicorn", \
  "--chdir=/home/frappe/frappe-bench/sites", \
  "--bind=0.0.0.0:8000", \
  "--threads=4", \
  "--workers=2", \
  "--worker-class=gthread", \
  "--worker-tmp-dir=/dev/shm", \
  "--timeout=120", \
  "--preload", \
  "frappe.app:application" \
]