process CUTADAPT_SUMMARY {
    label 'process_single'
    publishDir "${params.outdir}/cutadapt", mode: params.publish_dir_mode

    conda "conda-forge::python=3.11"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.11' :
        'biocontainers/python:3.11' }"

    input:
    path(log_files)

    output:
    path "summary.csv"          , emit: csv
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    DetectPrimer.py \\
        ${log_files} \\
        --out summary.csv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
