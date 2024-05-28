/*
 * Copyright (c) 2022-2024 Works Applications Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.worksap.nlp.lucene.sudachi.ja

import com.worksap.nlp.lucene.sudachi.ja.attributes.MorphemeAttribute
import com.worksap.nlp.lucene.sudachi.ja.attributes.MorphemeConsumerAttribute
import com.worksap.nlp.sudachi.Morpheme
import org.apache.logging.log4j.LogManager
import org.apache.lucene.analysis.TokenFilter
import org.apache.lucene.analysis.TokenStream
import org.apache.lucene.analysis.tokenattributes.CharTermAttribute
import org.apache.lucene.analysis.tokenattributes.KeywordAttribute

/**
 * Sets the content of [CharTermAttribute] to the returned value of [MorphemeFieldFilter.value]
 * method.
 *
 * To prevent terms from being rewritten use an instance of
 * [org.apache.lucene.analysis.miscellaneous.SetKeywordMarkerFilter] or a custom [TokenFilter] that
 * sets the [KeywordAttribute] before this [TokenStream].
 *
 * Values of [MorphemeAttribute] are used to produce the term.
 */
abstract class MorphemeFieldFilter(input: TokenStream) : TokenFilter(input) {
  @JvmField protected val morphemeAtt = existingAttribute<MorphemeAttribute>()
  @JvmField protected val keywordAtt = addAttribute<KeywordAttribute>()
  @JvmField protected val termAtt = addAttribute<CharTermAttribute>()
  @JvmField
  protected val consumer =
      addAttribute<MorphemeConsumerAttribute> { it.updateCurrentConsumers(this, input) }

  /**
   * Override this method to customize returned value. This method will not be called if
   * [MorphemeAttribute] contained `null`.
   */
  protected open fun value(m: Morpheme): CharSequence? = m.surface()

  override fun incrementToken(): Boolean {
    if (!input.incrementToken()) {
      return false
    }
    val m = morphemeAtt.getMorpheme() ?: return true
    var term: CharSequence? = null
    if (consumer.shouldConsume(this)) {
      if (!keywordAtt.isKeyword) {
        term = value(m)
      }
      if (term == null) {
        term = m.surface()
      }
      termAtt.setEmpty().append(term)
    }
    return true
  }

  override fun reset() {
    super.reset()
    if (!consumer.shouldConsume(this)) {
      logger.warn(
          "an instance of ${javaClass.name} is a no-op, it is not a filter which produces terms in one of your filter chains")
    }
  }

  companion object {
    private val logger = LogManager.getLogger(MorphemeFieldFilter::class.java)
  }
}
