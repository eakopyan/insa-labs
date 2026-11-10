FROM node:22-alpine

WORKDIR /app

COPY . . 

RUN npm install sync-request

EXPOSE 80

CMD ["node", "CalcService.js"]
