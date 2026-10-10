# Use an official Python image as the base
FROM public.ecr.aws/lambda/python:3.12

# Copy the current directory contents into the container
COPY ./app ${LAMBDA_TASK_ROOT}

# Install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip3 install --no-cache-dir -r requirements.txt

# Set the default command to run when the container starts
CMD ["lambda.lambda_handler"]