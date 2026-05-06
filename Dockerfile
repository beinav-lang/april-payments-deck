FROM python:3.11-slim

WORKDIR /app

# No third-party deps — comments_server.py is stdlib only.
COPY comments_server.py ./
COPY april_2026_payments_summary_slides.html ./
# Optional: if there's a data subdir referenced by the deck. Best-effort copies that don't fail
# if the target doesn't exist (Dockerfile silently skips missing globs).
COPY assets ./assets

# /data is the persistent volume mount point. comments.json lives there in production.
RUN mkdir -p /data
ENV COMMENTS_FILE=/data/comments.json

EXPOSE 8080
ENV PORT=8080

# Use shell form so $PORT (set by Render / Fly / etc.) is expanded at runtime; falls back to 8080 locally
CMD python comments_server.py ${PORT:-8080}
