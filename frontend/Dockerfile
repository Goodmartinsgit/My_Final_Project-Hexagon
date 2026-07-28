# LOCAL DEVELOPMENT ONLY
# This Dockerfile is used by docker-compose to serve the static frontend
# files locally via nginx, giving full local parity with the production
# setup without needing AWS.
#
# Production deployment: the frontend-deploy.yml GitHub Actions workflow
# syncs the static files directly to the private S3 bucket and invalidates
# the CloudFront cache. This Dockerfile is never used in production.

FROM nginx:alpine

COPY . /usr/share/nginx/html/

EXPOSE 80