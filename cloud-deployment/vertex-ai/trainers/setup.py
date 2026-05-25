from setuptools import setup, find_packages

setup(
    name="mychannel_trainer",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "google-cloud-bigquery",
        "google-cloud-storage",
        "scikit-learn==1.3.2",
        "pandas",
        "numpy",
        "joblib",
        "db-dtypes",
        "pyarrow",
        "pandas-gbq",
    ],
)
