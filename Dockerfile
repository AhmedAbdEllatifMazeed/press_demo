# syntax = docker/dockerfile:experimental
FROM ubuntu:22.04

# Set environment variables
ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    BENCH_DIR=/home/frappe/frappe-bench \
    BENCH_NAME=frappe-bench \
    NODE_OPTIONS=--max-old-space-size=8192 \
    PATH="/home/frappe/.local/bin:/home/frappe/frappe-bench/env/bin:$PATH"

# Install system dependencies
RUN --mount=type=cache,target=/var/cache/apt apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    mariadb-client \
    libmariadb-dev \
    pkg-config \
    wget \
    curl \
    supervisor \
    software-properties-common \
    gnupg \
    ca-certificates \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3.10-distutils \
    redis-server \
    redis-tools \
    cron \
    golang-go \
    jq wait-for-it \
    && rm -rf /var/lib/apt/lists/*


# copy supervisord.conf    
#COPY resources/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# Install wkhtmltopdf
RUN apt-get update && apt-get install -y wkhtmltopdf

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn


RUN mkdir -p /etc/supervisor/conf.d

# Create new user with home directory, improve docker compatibility with UID/GID 1000,
# add user to sudo group, allow passwordless sudo, switch to that user
# and change directory to user home directory
RUN groupadd -g 1000 frappe \
    && useradd --no-log-init -r -m -u 1000 -g 1000 -G sudo frappe \
    && echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers



#RUN chown frappe:frappe /etc/supervisor/conf.d 
COPY --chown=root:root resources/supervisord.conf /etc/supervisor/conf.d/frappe-bench.conf


# Switch to frappe user
USER frappe
WORKDIR /home/frappe

# Install Python tools
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python3.10 get-pip.py && \
    python3.10 -m pip install --upgrade pip wheel setuptools

# Install Frappe Bench
RUN python3.10 -m pip install frappe-bench

# Initialize Bench with explicit Python version
RUN /home/frappe/.local/bin/bench init frappe-bench --skip-redis-config-generation


RUN cd frappe-bench && \
./env/bin/pip install gunicorn && \
/home/frappe/.local/bin/bench setup requirements

# Install Frappe framework (skip if already exists)
# RUN cd frappe-bench && \
#    if [ ! -d "apps/frappe" ]; then \
#        /home/frappe/.local/bin/bench get-app frappe; \
#    fi

# # Create the Press app if it doesn't exist (bypass interactive prompt)
# # Install the Press app with --resolve-deps to handle missing dependencies
# RUN cd frappe-bench && \
#     if [ ! -d "apps/press" ]; then \
#         /home/frappe/.local/bin/bench get-app press; \
#     fi 

WORKDIR /home/frappe/frappe-bench/sites

COPY common_site_config.json /home/frappe/frappe-bench/sites/common_site_config.json
#COPY resources/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf


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