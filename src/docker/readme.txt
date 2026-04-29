SWAN 41.10 Docker Container

Deze container kan SWAN 41.10 draaien. De input data wordt verwacht in de /data directory.

In de input data moet een folder RUN zitten met een invoer file (.SWN) voor SWAN.

Commando om de container te draaien:
docker run <containernaam> -v <input folder>:/data -e INPUT=<Swanfile zonder .SWN> -t swan:41.10