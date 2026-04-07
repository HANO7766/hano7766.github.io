# Usa la imagen oficial de Microsoft para Jekyll (basada en Debian Bullseye)
# Esta imagen tiene glibc nativo, lo que permite que sass-embedded funcione correctamente
FROM mcr.microsoft.com/devcontainers/jekyll:2-bullseye

# Configura git para evitar el error de "dubious ownership"
RUN git config --global --add safe.directory /srv/jekyll

# Copia los archivos de dependencias y pre-instala todas las gemas
COPY Gemfile Gemfile.lock /srv/jekyll/
WORKDIR /srv/jekyll
RUN bundle install

# Expone el puerto de Jekyll
EXPOSE 4000

# El directorio del proyecto se monta en tiempo de ejecución
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0", "--livereload", "--force_polling", "--future"]
