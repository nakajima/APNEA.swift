FROM swift:5.10

# Install redis
RUN apt-get update && apt-get install -y redis-server curl

# Set the working directory
WORKDIR /app

# Copy the source code
ADD . /app

# Build the application
# RUN swift package update
RUN swift build -c release --product APNEAServer

RUN mkdir /app/bin
RUN cp /app/.build/release/APNEAServer /app/bin/APNEAServer

# Expose the port
EXPOSE 4567

ENV REDIS_URL=redis://host.docker.internal:6379

# Run the application
ENTRYPOINT ["/app/bin/APNEAServer"]
