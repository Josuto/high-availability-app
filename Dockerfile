# Use the official Node.js image as the base image
FROM node:23.1.0-alpine

# Install pnpm globally
RUN npm install -g pnpm

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json to the working directory
COPY package*.json ./

# Install the production dependencies only (i.e., without the devDependencies)
RUN pnpm install --production

# Copy the compiled application (pnpm build is to be run before building the image)
COPY dist ./dist

# Create a non-root user to run the application
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs && \
    chown -R nestjs:nodejs /app

# Switch to non-root user
USER nestjs

# Expose the application port (informative, use -p to map ports)
EXPOSE 3000

# Start the application
CMD [ "pnpm", "start:prod" ]
