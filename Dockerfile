FROM amazonlinux:2

# 必要なツールをインストール（tar, unzip, python, pipなど）
RUN yum update -y && \
    yum install -y \
        tar \
        gzip \
        unzip \
        python3 \
        python3-pip

# Lambda Runtime Interface Client をインストール
RUN pip3 install awslambdaric

# 🔽 RIE を追加（これが必要！）
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/local/bin/aws-lambda-rie
RUN chmod +x /usr/local/bin/aws-lambda-rie

# 作業ディレクトリ
WORKDIR /var/task

# aws-nukeのバイナリと設定
COPY resources/aws-nuke-v2.25.0-linux-amd64.tar.gz .
COPY config/nuke-config.yaml .

RUN tar -xzf aws-nuke-v2.25.0-linux-amd64.tar.gz && \
    mv aws-nuke-v2.25.0-linux-amd64 aws-nuke && \
    chmod +x aws-nuke

# Lambdaハンドラコードと依存
COPY lambda/nuke_handler.py .
COPY lambda/requirements.txt .
RUN pip3 install -r requirements.txt

# Lambdaエントリポイントを修正
ENTRYPOINT ["/usr/local/bin/aws-lambda-rie", "/usr/bin/python3", "-m", "awslambdaric"]
CMD ["nuke_handler.lambda_handler"]