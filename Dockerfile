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

# Expose the application port (informative, use -p to map ports)
EXPOSE 3000

# Start the application
CMD [ "pnpm", "start:prod" ]