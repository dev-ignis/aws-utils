server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${server_name};

    location / {
        proxy_pass http://127.0.0.1/${front_end_image != "" ? front_end_port : backend_port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:${backend_port}/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ask-specialist {
        proxy_pass http://localhost:8080/chatgpt;
    }

    location /specifics-list {
        proxy_pass http://localhost:8080/concern;
    }

    location /swagger/ {
        proxy_pass http://127.0.0.1:${backend_port}/swagger/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /users {
        proxy_pass http://127.0.0.1:${backend_port}/users;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
