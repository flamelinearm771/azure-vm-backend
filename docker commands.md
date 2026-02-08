docker build --no-cache -t upload-api:v2 .

docker tag upload-api:v2 videotranscriberacr.azurecr.io/upload-api:v2

docker push videotranscriberacr.azurecr.io/upload-api:v2

az containerapp update \
  --name upload-api \
  --resource-group video-transcription-pipeline \
  --image videotranscriberacr.azurecr.io/upload-api:v2


az containerapp logs show \
  --name upload-api \
  --resource-group video-transcription-pipeline \
  --follow

