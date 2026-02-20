process ITSXPRESS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/itsxpress:2.0.0--pyhdfd78af_0' :
        'biocontainers/itsxpress:2.0.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    tuple val(meta), path("*.log")      , emit: log
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (meta.single_end) {
        """
        itsxpress \
            --fastq ${reads} \
            --single_end \
            --outfile ${prefix}.trim.fastq.gz \
            --threads ${task.cpus} \
            --log ${prefix}.log \
            ${args}

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            itsxpress: \$(itsxpress --version 2>&1 | sed -n 's/.*version //p' | sed 's/ .*//')
        END_VERSIONS
        """
    } else {
        """
        itsxpress \
            --fastq ${reads[0]} \
            --fastq2 ${reads[1]} \
            --outfile ${prefix}_1.trim.fastq.gz \
            --outfile2 ${prefix}_2.trim.fastq.gz \
            --threads ${task.cpus} \
            --log ${prefix}.log \
            ${args}

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            itsxpress: \$(itsxpress --version 2>&1 | sed -n 's/.*version //p' | sed 's/ .*//')
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (meta.single_end) {
        """
        echo | gzip > ${prefix}.trim.fastq.gz
        touch ${prefix}.log

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            itsxpress: 2.0.0
        END_VERSIONS
        """
    } else {
        """
        echo | gzip > ${prefix}_1.trim.fastq.gz
        echo | gzip > ${prefix}_2.trim.fastq.gz
        touch ${prefix}.log

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            itsxpress: 2.0.0
        END_VERSIONS
        """
    }
}
