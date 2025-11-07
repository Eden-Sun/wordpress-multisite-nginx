FROM wordpress:fpm

# Install dependencies and FFI extension
RUN apt-get update && apt-get install -y \
    libffi-dev \
    git \
    && docker-php-ext-install ffi \
    && docker-php-ext-enable ffi \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
