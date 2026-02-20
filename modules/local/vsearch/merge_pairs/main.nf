process VSEARCH_MERGEPAIRS {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::vsearch=2.28.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/vsearch:2.28.1--h6a68c12_0':
        'biocontainers/vsearch:2.28.1--h6a68c12_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.merged.fastq.gz"), emit: reads
    tuple val(meta), path("*.log")            , emit: log
    path "versions.yml"                       , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    vsearch \
        --fastq_mergepairs ${reads[0]} \
        --reverse ${reads[1]} \
        --fastqout ${prefix}.merged.fastq \
        --threads $task.cpus \
        --log ${prefix}.log \
        $args

    gzip ${prefix}.merged.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vsearch: \$(vsearch --version 2>&1 | head -n 1 | sed 's/vsearch //g' | sed 's/,.*//g' | sed 's/^v//')
    END_VERSIONS
    """
}
