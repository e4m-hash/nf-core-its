include { CUTADAPT } from '../../../modules/nf-core/cutadapt/main.nf'
include { CUTADAPT_SUMMARY } from '../../../modules/local/cutadapt/summary/main.nf'

include { VSEARCH_MERGEPAIRS } from '../../../modules/local/vsearch/merge_pairs/main.nf'
include { VSEARCH_MERGEPAIRS_SUMMARY } from '../../../modules/local/vsearch/summary/main.nf'

include { ITSXPRESS } from '../../../modules/local/itsxpress/main.nf'
include { VSEARCH_QUALITY_FILTERING } from '../../../modules/local/vsearch/quality_filtering/main.nf'

include { QIIME2_IMPORT } from '../../../modules/local/qiime2/import/main.nf'
include { QIIME2_DEREPLICATE } from '../../../modules/local/qiime2/dereplicate/main.nf'
include { QIIME2_VSEARCH_UCHIME_DENOVO } from '../../../modules/local/qiime2/vsearch_uchime-denovo/main.nf'
include { QIIME2_FILTERING_FEATURE } from '../../../modules/local/qiime2/filtering_feature/main.nf'
include { QIIME2_FILTER_SEQUENCE } from '../../../modules/local/qiime2/filter_seq/main.nf'
include { QIIME2_CLUSTER_FEATURE } from '../../../modules/local/qiime2/cluster_feature/main.nf'
include { QIIME2_VISUALIZATION } from '../../../modules/local/qiime2/visualiztaion/main.nf'


workflow preprocessing {
    take:
    ch_reads // channel: [ val(meta), [ reads_1, reads_2 ] ]

    main:
    ch_versions = channel.empty()

    CUTADAPT (
        ch_reads
    )

    ch_versions = ch_versions.mix(CUTADAPT.out.versions_cutadapt)
    ch_all_logs = CUTADAPT.out.log
        .map { meta, log -> log }
        .collect()

    CUTADAPT_SUMMARY (
        ch_all_logs
    )

    VSEARCH_MERGEPAIRS (
        CUTADAPT.out.reads
    )

    ch_versions = ch_versions.mix(VSEARCH_MERGEPAIRS.out.versions)
    ch_all_logs = VSEARCH_MERGEPAIRS.out.log
        .map { meta, log -> log }
        .collect()

    VSEARCH_MERGEPAIRS_SUMMARY(
        ch_all_logs
    )

    ch_merged_reads = VSEARCH_MERGEPAIRS.out.reads
        .map { meta, reads ->
            def new_meta = meta + [single_end: true]
            [new_meta, reads]
        }
    
    ITSXPRESS(
        ch_merged_reads
    )

    ch_versions = ch_versions.mix(ITSXPRESS.out.versions)

    VSEARCH_QUALITY_FILTERING(
        ITSXPRESS.out.reads
    )
    
    ch_versions = ch_versions.mix(VSEARCH_QUALITY_FILTERING.out.versions)

    ch_manifest_file = VSEARCH_QUALITY_FILTERING.out.reads
            .map { meta, reads ->
                def filepath = reads instanceof List ? reads[0] : reads
                return "${meta.id},${filepath.toAbsolutePath()},forward"
            }
            .collectFile(
                name: 'manifest.csv', 
                newLine: true, 
                storeDir: "${params.outdir}/pipeline_info", 
                sort: true,
                seed: 'sample-id,absolute-filepath,direction' 
            )
            .map { manifest_file -> 
                tuple( [id:'all_samples', single_end:true], manifest_file ) 
            }

    QIIME2_IMPORT(
        ch_manifest_file
    )

    QIIME2_DEREPLICATE(
        QIIME2_IMPORT.out.qza
    )

    QIIME2_VSEARCH_UCHIME_DENOVO(
        QIIME2_DEREPLICATE.out.derep
    )

    QIIME2_FILTERING_FEATURE(
        QIIME2_VSEARCH_UCHIME_DENOVO.out.uchime
    )

    QIIME2_FILTER_SEQUENCE(
        QIIME2_FILTERING_FEATURE.out.nonchimeric
    )

    QIIME2_CLUSTER_FEATURE(
        QIIME2_FILTER_SEQUENCE.out.rep_seq_nonchimeric
    )

    QIIME2_VISUALIZATION(
        QIIME2_CLUSTER_FEATURE.out.clustered
    )

    emit:
    versions = ch_versions
}
