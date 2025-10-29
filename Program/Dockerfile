# Program/Dockerfile

# --- Етап 1: Збірка (Builder) ---
FROM ubuntu:22.04 as builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y build-essential cmake git libssl-dev curl
WORKDIR /app
COPY . .
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build

# --- Етап 2: Виконання (Runner) ---
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y libssl3 libcurl4 ca-certificates && rm -rf /var/lib/apt/lists/*
RUN update-ca-certificates
WORKDIR /app
COPY --from=builder /app/build/bin/NAC_ADAPTIVE_CPP .
COPY --from=builder /app/build/external/cpr/cpr/libcpr.so* /usr/lib/
RUN ldconfig
# ## ЗМІНА ТУТ: Видаляємо копіювання .env ##
# COPY .env .
CMD ["./NAC_ADAPTIVE_CPP"]