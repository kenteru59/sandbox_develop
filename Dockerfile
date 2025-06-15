# Lambda対応のベースイメージを使用（Python 3.11）
FROM public.ecr.aws/lambda/python:3.11

# tar コマンドをインストール
RUN yum install -y tar gzip

# 作業ディレクトリ
WORKDIR /var/task

# aws-nuke バイナリと設定ファイルを配置
COPY resources/aws-nuke-v3.56.1-linux-amd64.tar.gz .
COPY config/nuke-config.yaml .

# aws-nuke を展開して配置
RUN tar -xzf aws-nuke-v3.56.1-linux-amd64.tar.gz && \
    chmod +x aws-nuke && \
    ./aws-nuke --version

# Lambda ハンドラーと依存ライブラリを配置
COPY lambda/nuke_handler.py .
COPY lambda/requirements.txt .

RUN pip3 install --no-cache-dir -r requirements.txt

# Lambdaのエントリポイント
CMD ["nuke_handler.lambda_handler"]
