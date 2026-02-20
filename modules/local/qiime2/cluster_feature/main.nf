process QIIME2_CLUSTER_FEATURE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(derep_nom_table), path(rep_seqs_nonchimeric)
    
    output:
    tuple val(meta), path("otu-table.qza"), path("otu-rep-seqs.qza"), emit: clustered
    path "versions.yml", emit: versions

    script:
    def args   = task.ext.args   ?: ''

    """
    qiime vsearch cluster-features-de-novo \
    --i-table ${derep_nom_table} \
    --i-sequences ${rep_seqs_nonchimeric} \
    --p-threads ${task.cpus} \
    --o-clustered-table otu-table.qza \
    --o-clustered-sequences otu-rep-seqs.qza \
    ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$(qiime --version | sed 's/q2cli version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
